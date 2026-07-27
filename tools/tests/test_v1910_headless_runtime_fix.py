from __future__ import annotations

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class V1910HeadlessRuntimeFixTests(unittest.TestCase):
    def test_release_version_is_1910(self) -> None:
        self.assertIn('config/version="1.9.11"', read("project/project.godot"))

    def test_headless_detection_uses_display_server_not_os_feature(self) -> None:
        v18 = read("project/scripts/campaign_battle_v18.gd")
        v19 = read("project/scripts/campaign_battle_v19.gd")
        self.assertNotIn('OS.has_feature("headless")', v18 + v19)
        self.assertIn('DisplayServer.get_name().to_lower() == "headless"', v18)
        self.assertIn('OS.get_environment("VBR_SMOKE_MISSION") != ""', v18)
        self.assertIn('CampaignState.test_forced_branch != ""', v18)

    def test_mission_six_automated_boot_skips_all_ui_waits(self) -> None:
        script = read("project/scripts/campaign_battle_v19.gd")
        finalizer = script[script.index("func _finalize_mission_six_boot") : script.index("func _load_first_mission")]
        self.assertIn("if not _is_headless_or_smoke_runtime():", finalizer)
        self.assertIn("else:", finalizer)
        self.assertIn('kingdom_choice = CampaignState.test_forced_branch', finalizer)
        self.assertIn('MISSION6_BOOT_FINALIZED branch=%s', finalizer)
        self.assertLess(finalizer.index("mission_six_intro_pending = false"), finalizer.index("_begin_player_turn()"))

    def test_both_workflows_require_mission_six_finalizer_marker(self) -> None:
        for workflow in (
            ".github/workflows/build-windows.yml",
            ".github/workflows/release-windows.yml",
        ):
            text = read(workflow)
            self.assertIn('grep -Fq "MISSION6_BOOT_FINALIZED branch=${branch}" "$log"', text)
            self.assertIn('"6:south" "6:north"', text)
            self.assertNotIn("continue-on-error", text)


if __name__ == "__main__":
    unittest.main()
