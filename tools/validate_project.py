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


def read(relative: str) -> str:
    path = ROOT / relative
    if not path.is_file():
        fail(f"missing required file: {relative}")
    return path.read_text(encoding="utf-8")


def check_json() -> None:
    count = 0
    for path in ROOT.rglob("*.json"):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            fail(f"invalid JSON {path.relative_to(ROOT)}: {exc}")
        count += 1
    if count < 36:
        fail(f"too few JSON resources: {count}")


def check_brackets() -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    gd_count = 0
    for path in ROOT.rglob("*.gd"):
        gd_count += 1
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
    if gd_count < 38:
        fail(f"too few GDScript files: {gd_count}")


def check_progression() -> None:
    progression = read("scripts/atac_progression.gd")
    catalog = read("scripts/combat_catalog.gd")
    attack_section = catalog.split("const MAGIC_ATTACKS", 1)[0]
    attack_ids = set(re.findall(r'^\t"([a-z0-9_]+)":\s*\{', attack_section, flags=re.MULTILINE))
    progression_ids: set[str] = set()
    for block in re.findall(r'"attacks":\s*\[([^\]]*)\]', progression):
        progression_ids.update(re.findall(r'"([a-z0-9_]+)"', block))
    missing = sorted(progression_ids - attack_ids)
    if missing:
        fail(f"progression references undefined attacks: {missing}")

    entry_count = len(re.findall(r'^\t"[a-z0-9_]+":\s*\{', progression, flags=re.MULTILINE))
    if entry_count != 34:
        fail(f"official progression must contain 34 ATAC entries, got {entry_count}")

    required_snippets = [
        '"alba": {', '"max_level": 40', '"alba_combo"',
        '"tic_tac": {', '"max_level": 80', '"max_energy": 250', '"mind_hypnosis"',
        '"zulwarn": {', '"max_level": 100', '"max_energy": 350', '"summon_clone"',
        '"altagrave": {', '"max_energy": 155', '"ice_age"',
        '"crimson": {', '"max_energy": 160', '"geno_flame"',
        '"panther": {', '"panther_teleport"',
        '"engineer": {', '"engineer_shield"',
        '"waiban": {', '"waiban_decoys"',
    ]
    for snippet in required_snippets:
        if snippet not in progression:
            fail(f"missing progression marker: {snippet}")

    smoke = read("scripts/atac_progression_smoke.gd")
    for marker in [
        'AtacProgression.attacks_for("panther", 15)',
        'AtacProgression.attacks_for("engineer", 35)',
        'CampaignState.character_atac("kamorge") != "barazaph"',
        'CampaignState.character_atac("kamorge") != "eigol"',
        'int(result.get("stat_points", 0)) != 3',
    ]:
        if marker not in smoke:
            fail(f"progression smoke missing marker: {marker}")


def check_project_metadata() -> None:
    project_text = read("project.godot")
    if 'config/version="2.0.1"' not in project_text:
        fail("project.godot version is not 2.0.1")
    export_text = read("export_presets.cfg")
    if 'application/product_version="2.0.1.0"' not in export_text:
        fail("Windows export version is not 2.0.1.0")
    scene = read("scenes/BattlePrototype.tscn")
    if 'res://scripts/campaign_battle_v20.gd' not in scene:
        fail("BattlePrototype is not registered to campaign_battle_v20.gd")
    for required in [
        "scenes/AllScriptsCompileSmoke.tscn",
        "scenes/AtacProgressionSmoke.tscn",
        "scenes/Mission6Smoke.tscn",
        "scenes/Mission7Smoke.tscn",
        "data/maps/mission_07.json",
        "data/balance/official_atac_balance_by_level.txt",
        "scenes/PerformanceSmoke.tscn",
        "CHANGELOG_2.0.1.txt",
        "README_2.0.1.md",
    ]:
        if not (ROOT / required).is_file():
            fail(f"missing required file: {required}")


def check_story_and_mission_seven() -> None:
    state = read("scripts/campaign_state.gd")
    battle = read("scripts/campaign_battle_v20.gd")
    mission3 = read("scripts/campaign_battle_v08.gd")
    mission_select = read("scripts/mission_select.gd")
    mission_map = json.loads(read("data/maps/mission_07.json"))

    for marker in [
        '"kamorge" and mission_number <= 3',
        'early_kamorge["atac"] = "barazaph"',
        'kamorge_data["atac"] = "eigol"',
        'const SOUTH_ALLIANCE_CHARACTERS: Array[String] = ["claire", "shion"]',
        'const NORTH_ALLIANCE_CHARACTERS: Array[String] = ["barlow", "milea", "puck"]',
        'elif mission_id == 7:',
    ]:
        source = state + read("scripts/campaign_battle.gd")
        if marker not in source:
            fail(f"story route marker missing: {marker}")

    for exact_kit in [
        'ione_unit.set_meta("attack_override", ["slash", "lunge", "long_lunge"])',
        'reyna_unit.set_meta("attack_override", ["slash", "lunge", "long_lunge"])',
        'zeira_unit.set_meta("attack_override", ["slash", "lunge", "long_lunge", "strong_slash"])',
    ]:
        if exact_kit not in mission3:
            fail(f"mission III starter kit missing: {exact_kit}")

    for marker in [
        'func _spawn_south_relief', 'func _spawn_north_relief',
        'clampi(maxi(25, enemy_level), 25, 100)',
        'clampi(maxi(15, enemy_level - 5), 15, 100)',
        '"milea", "panther"', '"puck", "engineer"',
        '"ganlon", "waiban"', 'func _spawn_ganlon_decoys',
        'func _animate_evil_heart_v20', 'func _animate_geno_flame_v20',
        'func _animate_rocket_v20', 'func _animate_ice_field_v20',
        'MISSION7_BOOT_OK', 'MISSION7_RELIEF_OK', 'MISSION7_VICTORY_OK',
        'TEST_LEVEL_SCALING_OK', 'func _apply_runtime_test_balance',
        'CampaignState.raise_character_level_floor',
    ]:
        if marker not in battle:
            fail(f"mission VII marker missing: {marker}")

    if len(mission_map.get("enemy_starts", {}).get("barbatos", [])) != 5:
        fail("mission VII must contain exactly five Barbatos guards")
    if len(mission_map.get("south_relief", {}).get("bots", [])) != 6:
        fail("south relief must contain six Rahabor")
    if len(mission_map.get("north_relief", {}).get("bots", [])) != 6:
        fail("north relief must contain six Matisse")

    button_count = mission_select.count("_add_mission_button(") - 1  # subtract function definition
    if button_count != 11:
        fail(f"mission selector must expose 11 mission/branch buttons, got {button_count}")


def check_visual_assets() -> None:
    required_slugs = [
        "alba", "amphisia", "haurol", "toreadore", "vedocorban",
        "crimson", "rahabar", "altagrave", "snow_soldier", "ratatosk",
        "panther", "engineer", "waiban", "solarus", "sarbelas",
    ]
    views = ["front", "back", "side", "three_quarter", "left", "right"]
    for slug in required_slugs:
        for view in views:
            path = ROOT / "assets" / "atac_views" / slug / f"{view}.png"
            if not path.is_file() or path.stat().st_size < 1500:
                fail(f"missing or empty ATAC view: {slug}/{view}.png")
    factory = read("scripts/atac_factory.gd")
    multiview = read("scripts/multiview_atac.gd")
    for slug in ["alba", "amphisia", "haurol", "toreadore", "vedocorban", "panther", "engineer", "waiban", "solarus", "sarbelas"]:
        if f'"{slug}"' not in factory or f'"{slug}"' not in multiview:
            fail(f"full-body ATAC is not registered: {slug}")
    if 'if slug in ["ratatosk", "rahabar"]' not in multiview:
        fail("Ratatosk/Rahabar forward-axis correction is missing")
    factory = read("scripts/atac_factory.gd")
    for slug in ["solarus", "sarbelas"]:
        if f'"{slug}"' not in factory:
            fail(f"new full-body model is not registered: {slug}")

    storyboard_modes = [
        "geno_flame", "evil_heart", "rocket_shot", "area_rocket",
        "frost", "storm_vortex", "ice_age",
    ]
    for mode in storyboard_modes:
        for index in range(1, 5):
            path = ROOT / "assets" / "vfx" / "storyboard" / mode / f"{index}.png"
            if not path.is_file() or path.stat().st_size < 1000:
                fail(f"missing storyboard frame: {mode}/{index}.png")


def check_shop_icons() -> None:
    state = read("scripts/campaign_state.gd")
    icons = re.findall(r'"icon":\s*"res://([^"]+)"', state)
    if len(icons) != 12:
        fail(f"shop must register 12 item icons, got {len(icons)}")
    for icon_path in icons:
        if not (ROOT / icon_path).is_file():
            fail(f"missing shop icon: {icon_path}")


def check_runtime_smoke_safety() -> None:
    story_smoke = read("scripts/story_smoke.gd")
    if "get_tree().change_scene_to_file" in story_smoke:
        fail("StorySmoke must not replace the active scene from _ready")
    death_smoke = read("scripts/death_cleanup_smoke.gd")
    if "remaining.has(enemy)" in death_smoke or "enemy_instance_id" not in death_smoke:
        fail("DeathCleanupSmoke must compare stable instance IDs")
    multiview = read("scripts/multiview_atac.gd")
    for marker in ["world_basis.determinant()", "world_basis.orthonormalized().inverse()"]:
        if marker not in multiview:
            fail(f"MultiViewAtac singular-basis guard is missing: {marker}")
    visibility_smoke = read("scripts/visibility_smoke.gd")
    for slug in ["panther", "engineer", "waiban"]:
        if f'"{slug}"' not in visibility_smoke:
            fail(f"VisibilitySmoke missing {slug}")
    workflow = read(".github/workflows/godot-ci.yml")
    for marker in [
        'VBR_SMOKE_MISSION=7 VBR_SMOKE_BRANCH="$branch"',
        'Mission7Smoke',
        'name: Vanguard-Bandits-Remaster-2.0.1-Windows',
        'timeout 90s "$GODOT"',
        'PerformanceSmoke',
    ]:
        if marker not in workflow:
            fail(f"workflow marker missing: {marker}")
    if "continue-on-error" in workflow:
        fail("workflow must not use continue-on-error")


def check_optimization_and_controls() -> None:
    state = read("scripts/campaign_state.gd")
    battle = read("scripts/campaign_battle.gd")
    battle_v08 = read("scripts/campaign_battle_v08.gd")
    battle_v18 = read("scripts/campaign_battle_v18.gd")
    battle_v20 = read("scripts/campaign_battle_v20.gd")
    performance = read("scripts/performance_guard.gd")
    multiview = read("scripts/multiview_atac.gd")

    for marker in [
        "func request_save_game", "func raise_character_level_floor",
        "return 75 + level * 25", "request_save_game()",
    ]:
        if marker not in state:
            fail(f"campaign progression optimization missing: {marker}")
    for marker in [
        "var damage_bonus: int = mini(20", "80 if killed_enemy else 0",
        "func _sync_runtime_progress_fields", 'stats["experience_needed"]',
    ]:
        if marker not in battle:
            fail(f"battle XP marker missing: {marker}")
    for marker in [
        "Сначала поверните ATAC стрелками", "func _choose_facing",
        'event.is_action_pressed("ui_up")', 'event.is_action_pressed("ui_right")',
        'end_turn_button.text = "Пропустить ход" if facing_ready',
    ]:
        if marker not in battle_v08:
            fail(f"arrow-facing marker missing: {marker}")
    for marker in [
        'root.name = gate_name', '"OpenLeafNorth"', '"OpenLeafSouth"',
        'blocked_cells.erase(Vector2i(x, int(gate_z_value)))',
        '"DefenseCastleCourtyard"', '"DefenseCastleBattlements"',
    ]:
        if marker not in battle_v18:
            fail(f"open castle gate/map marker missing: {marker}")
    for marker in [
        "TEST_LEVEL_SCALING_OK", "enemy_average - 3",
        "func _scale_runtime_ally", "CampaignState.request_save_game(0.20)",
        'CinematicVfx.play(self, "evil_heart"',
        'CinematicVfx.play(self, "storm_vortex"',
    ]:
        if marker not in battle_v20:
            fail(f"runtime scaling/VFX marker missing: {marker}")
    for marker in [
        "MAX_TRANSIENT_FX: int = 96", "LOG_FLUSH_INTERVAL: float = 30.0",
        "FX_CLEANUP_INTERVAL: float = 12.0", "func _trim_transient_fx",
        "OS.low_processor_usage_mode = true",
    ]:
        if marker not in performance:
            fail(f"performance guard marker missing: {marker}")
    for marker in [
        "VIEW_UPDATE_INTERVAL: float = 0.18", "SHARED_SHADOW_MESH",
        "sync_elapsed >= 0.12", 'if slug in ["ratatosk", "rahabar"]',
    ]:
        if marker not in multiview:
            fail(f"multiview optimization marker missing: {marker}")
    performance_smoke = read("scripts/performance_smoke.gd")
    if 'PERFORMANCE_SMOKE_OK' not in performance_smoke or 'range(130)' not in performance_smoke:
        fail("PerformanceSmoke is incomplete")
    movement_smoke = read("scripts/movement_input_smoke.gd")
    if 'battle.call("_choose_facing", Vector2i(1, 0))' not in movement_smoke:
        fail("MovementInputSmoke does not verify arrow facing")


def main() -> None:
    check_json()
    check_brackets()
    check_progression()
    check_project_metadata()
    check_story_and_mission_seven()
    check_visual_assets()
    check_shop_icons()
    check_runtime_smoke_safety()
    check_optimization_and_controls()
    print("VALIDATION_OK")


if __name__ == "__main__":
    main()
