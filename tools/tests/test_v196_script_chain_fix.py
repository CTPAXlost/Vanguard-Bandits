import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V196ScriptChainFixTests(unittest.TestCase):
    def test_base_script_does_not_reference_subclass_mission_member(self):
        text = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        block = text[text.index("battle_initialized =") : text.index("_begin_player_turn()", text.index("battle_initialized ="))]
        self.assertNotIn("[mission_number,", block)
        self.assertIn("CampaignState.current_mission", block)
        self.assertIn("BATTLE_READY_OK", block)

    def test_script_chain_smoke_loads_every_battle_layer(self):
        text = (PROJECT / "scripts/script_chain_smoke.gd").read_text(encoding="utf-8")
        for name in [
            "battle_prototype.gd", "campaign_battle.gd", "campaign_battle_v08.gd",
            "campaign_battle_v12.gd", "campaign_battle_v18.gd", "campaign_battle_v19.gd",
        ]:
            self.assertIn(name, text)
        self.assertIn("SCRIPT_CHAIN_SMOKE_OK", text)

    def test_both_workflows_run_script_chain_before_battle_scene(self):
        for workflow_name in ["build-windows.yml", "release-windows.yml"]:
            text = (ROOT / ".github/workflows" / workflow_name).read_text(encoding="utf-8")
            chain_pos = text.index("Runtime parse test for battle script chain")
            battle_pos = text.index("Runtime smoke test for battle scene")
            self.assertLess(chain_pos, battle_pos)
            self.assertIn("script_chain_smoke.gd", text)
            self.assertIn("SCRIPT_CHAIN_SMOKE_OK layers=6", text)
            self.assertNotIn("continue-on-error", text)

    def test_version(self):
        text = (PROJECT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.6"', text)


if __name__ == "__main__":
    unittest.main()
