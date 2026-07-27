import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
WORKFLOWS = [
    ROOT / ".github/workflows/build-windows.yml",
    ROOT / ".github/workflows/release-windows.yml",
]


class V196ScriptChainFixTests(unittest.TestCase):
    def test_base_script_does_not_reference_subclass_mission_member(self):
        text = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        block = text[text.index("battle_initialized =") : text.index("_begin_player_turn()", text.index("battle_initialized ="))]
        self.assertNotIn("mission_number", block)
        self.assertIn("CampaignState.current_mission", block)
        self.assertIn("BATTLE_READY_OK", block)

    def test_invalid_standalone_script_chain_smoke_is_gone(self):
        self.assertFalse((PROJECT / "scripts/script_chain_smoke.gd").exists())
        for workflow in WORKFLOWS:
            text = workflow.read_text(encoding="utf-8")
            self.assertNotIn("--script res://scripts/script_chain_smoke.gd", text)
            self.assertNotIn("SCRIPT_CHAIN_SMOKE_OK", text)

    def test_normal_scene_boot_compiles_full_inheritance_chain_with_autoloads(self):
        scene = (PROJECT / "scenes/MissionBootSmoke.tscn").read_text(encoding="utf-8")
        script = (PROJECT / "scripts/mission_boot_smoke.gd").read_text(encoding="utf-8")
        battle_scene = (PROJECT / "scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        self.assertIn('path="res://scenes/BattlePrototype.tscn"', scene)
        self.assertIn('instance=ExtResource("2")', scene)
        self.assertIn('res://scripts/campaign_battle_v19.gd', battle_scene)
        self.assertIn("CampaignState.prepare_mission_for_test", script)
        self.assertIn("battle_initialized", script)
        self.assertIn("MISSION_BOOT_SMOKE_OK", script)

    def test_both_workflows_run_normal_boot_before_other_runtime_smokes(self):
        for workflow in WORKFLOWS:
            text = workflow.read_text(encoding="utf-8")
            boot_pos = text.index("Blocking boot smoke for missions 1-6")
            battle_pos = text.index("Runtime smoke test for battle scene")
            self.assertLess(boot_pos, battle_pos)
            self.assertIn("MissionBootSmoke.tscn", text)
            self.assertIn('grep -Fq "MISSION_BOOT_SMOKE_OK mission=${mission} branch=${branch}"', text)
            self.assertNotIn("continue-on-error", text)

    def test_version(self):
        text = (PROJECT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.13"', text)


if __name__ == "__main__":
    unittest.main()
