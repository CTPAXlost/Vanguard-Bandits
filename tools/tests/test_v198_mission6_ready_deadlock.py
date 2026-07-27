from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def test_release_version_is_198() -> None:
    assert 'config/version="1.9.8"' in read("project/project.godot")


def test_mission_six_finalizer_is_independent_from_parent_ready_completion() -> None:
    script = read("project/scripts/campaign_battle_v19.gd")
    ready = script[script.index("func _ready() -> void:") : script.index("func _finalize_mission_six_boot")]
    assert 'call_deferred("_finalize_mission_six_boot")' in ready
    assert ready.index('call_deferred("_finalize_mission_six_boot")') < ready.index("await super._ready()")
    finalizer = script[script.index("func _finalize_mission_six_boot") : script.index("func _load_first_mission")]
    for token in (
        "mission_six_boot_started",
        "mission_six_boot_finalized",
        "player_party.size() != 5",
        "_apply_kingdom_choice()",
        "mission_six_intro_pending = false",
        "_begin_player_turn()",
    ):
        assert token in finalizer


def test_mission_six_smoke_passes_branch_explicitly_and_fails_on_timeout() -> None:
    smoke = read("project/scripts/mission6_smoke.gd")
    assert "_wait_for_mission_six(battle, 1200, branch)" in smoke
    assert "func _wait_for_mission_six(battle: Node, frames: int, branch: String) -> bool:" in smoke
    assert "return true" in smoke
    assert "return false" in smoke
    assert "mission six normal lifecycle timed out" in smoke


def test_boot_smoke_cleans_battle_before_quitting_and_reports_state() -> None:
    smoke = read("project/scripts/mission_boot_smoke.gd")
    assert "await _clean_shutdown(battle, 0)" in smoke
    assert "battle.queue_free()" in smoke
    assert "await get_tree().process_frame" in smoke
    for field in (
        "intro_pending=",
        "choice=",
        "boot_started=",
        "boot_finalized=",
        "action=",
        "phase=",
    ):
        assert field in smoke


def test_build_workflows_remain_blocking() -> None:
    for workflow in (
        ".github/workflows/build-windows.yml",
        ".github/workflows/release-windows.yml",
    ):
        text = read(workflow)
        assert "continue-on-error" not in text
        assert "Blocking boot smoke for missions 1-6" in text
        assert '"6:south" "6:north"' in text
        assert "MISSION6_SMOKE_OK" in text
        assert "--export-release" in text or "Export Windows x64" in text


def load_tests(loader: unittest.TestLoader, tests: unittest.TestSuite, pattern: str | None) -> unittest.TestSuite:
    suite = unittest.TestSuite()
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            suite.addTest(unittest.FunctionTestCase(value, description=name))
    return suite
