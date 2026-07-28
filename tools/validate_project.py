#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message: str) -> None:
    print(f"VALIDATION_FAILED: {message}", file=sys.stderr)
    raise SystemExit(1)


def check_json() -> None:
    for path in ROOT.rglob("*.json"):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            fail(f"invalid JSON {path.relative_to(ROOT)}: {exc}")


def check_brackets() -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        stack: list[tuple[str, int]] = []
        in_string: str | None = None
        escaped = False
        in_comment = False
        line = 1
        for char in text:
            if char == "\n":
                line += 1
                in_comment = False
                continue
            if in_comment:
                continue
            if in_string is not None:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == in_string:
                    in_string = None
                continue
            if char == "#":
                in_comment = True
                continue
            if char in {'"', "'"}:
                in_string = char
                continue
            if char in "([{":
                stack.append((char, line))
            elif char in ")]}" and (not stack or stack.pop()[0] != pairs[char]):
                fail(f"bracket mismatch in {path.relative_to(ROOT)} line {line}")
        if stack:
            fail(f"unclosed bracket in {path.relative_to(ROOT)} line {stack[-1][1]}")


def check_progression() -> None:
    progression = (ROOT / "scripts/atac_progression.gd").read_text(encoding="utf-8")
    catalog = (ROOT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
    attack_section = catalog.split("const MAGIC_ATTACKS", 1)[0]
    attack_ids = set(re.findall(r'^\t"([a-z0-9_]+)":\s*\{', attack_section, flags=re.MULTILINE))
    progression_ids: set[str] = set()
    for block in re.findall(r'"attacks":\s*\[([^\]]*)\]', progression):
        progression_ids.update(re.findall(r'"([a-z0-9_]+)"', block))
    missing = sorted(progression_ids - attack_ids)
    if missing:
        fail(f"progression references undefined attacks: {missing}")

    required_snippets = [
        '"alba": {', '"max_level": 40', '"alba_combo"',
        '"tic_tac": {', '"max_level": 80', '"max_energy": 250', '"mind_hypnosis"',
        '"zulwarn": {', '"max_level": 100', '"max_energy": 350', '"summon_clone"',
        '"altagrave": {', '"max_energy": 155',
        '"crimson": {', '"max_energy": 160',
    ]
    for snippet in required_snippets:
        if snippet not in progression:
            fail(f"missing progression marker: {snippet}")


def check_project_metadata() -> None:
    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    if 'config/version="1.9.19"' not in project_text:
        fail("project.godot version is not 1.9.19")
    export_text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    if 'application/product_version="1.9.19.0"' not in export_text:
        fail("Windows export version is not 1.9.19.0")
    for required in [
        "scenes/AllScriptsCompileSmoke.tscn",
        "scenes/AtacProgressionSmoke.tscn",
        "scenes/Mission6Smoke.tscn",
        "data/balance/official_atac_balance_by_level.txt",
    ]:
        if not (ROOT / required).is_file():
            fail(f"missing required file: {required}")


def check_shop_icons() -> None:
    state = (ROOT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
    for icon_path in re.findall(r'"icon":\s*"res://([^"]+)"', state):
        if not (ROOT / icon_path).is_file():
            fail(f"missing shop icon: {icon_path}")



def check_runtime_smoke_safety() -> None:
    story_smoke = (ROOT / "scripts/story_smoke.gd").read_text(encoding="utf-8")
    if "get_tree().change_scene_to_file" in story_smoke:
        fail("StorySmoke must not replace the active scene from _ready")
    for marker in [
        'await _validate_branch("stay_and_fight"',
        'await _validate_branch("seek_southern_aid"',
        'print("STORY_SMOKE_OK")',
    ]:
        if marker not in story_smoke:
            fail(f"StorySmoke missing marker: {marker}")

    death_smoke = (ROOT / "scripts/death_cleanup_smoke.gd").read_text(encoding="utf-8")
    if "remaining.has(enemy)" in death_smoke:
        fail("DeathCleanupSmoke passes a freed object into TypedArray.has")
    if "enemy_instance_id" not in death_smoke:
        fail("DeathCleanupSmoke does not compare stable instance IDs")

    multiview = (ROOT / "scripts/multiview_atac.gd").read_text(encoding="utf-8")
    for marker in ["world_basis.determinant()", "world_basis.orthonormalized().inverse()"]:
        if marker not in multiview:
            fail(f"MultiViewAtac singular-basis guard is missing: {marker}")

    workflow = (ROOT / ".github/workflows/godot-ci.yml").read_text(encoding="utf-8")
    if 'timeout 90s "$GODOT"' not in workflow:
        fail("runtime smoke timeout is not capped at 90 seconds")
    if "continue-on-error" in workflow:
        fail("workflow must not use continue-on-error")


def main() -> None:
    check_json()
    check_brackets()
    check_progression()
    check_project_metadata()
    check_shop_icons()
    check_runtime_smoke_safety()
    print("VALIDATION_OK")


if __name__ == "__main__":
    main()
