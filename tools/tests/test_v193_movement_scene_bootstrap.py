import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class MovementSceneBootstrapTests(unittest.TestCase):
    def test_smoke_instantiates_battle_after_campaign_preparation(self):
        scene = (ROOT / "project/scenes/MovementInputSmoke.tscn").read_text(encoding="utf-8")
        script = (ROOT / "project/scripts/movement_input_smoke.gd").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertNotIn("BattlePrototype.tscn", scene)
        self.assertIn('preload("res://scenes/BattlePrototype.tscn")', script)
        self.assertIn("CampaignState.prepare_mission_for_test(1)", script)
        self.assertIn("BATTLE_SCENE.instantiate()", script)
        self.assertIn('--quit-after 1800', workflow)
        self.assertNotIn("continue-on-error", workflow)

if __name__ == "__main__":
    unittest.main()
