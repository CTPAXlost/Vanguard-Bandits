from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SMOKE = ROOT / "project/scripts/movement_input_smoke.gd"
PROJECT = ROOT / "project/project.godot"

class V192MovementSmokeHotfixTests(unittest.TestCase):
    def test_smoke_waits_for_full_battle_initialisation(self):
        text = SMOKE.read_text(encoding="utf-8")
        self.assertIn("range(600)", text)
        self.assertIn("_find_player_unit", text)
        self.assertIn('battle.get("units")', text)
        self.assertIn("not reachable.is_empty()", text)

    def test_project_version(self):
        self.assertIn('config/version="1.9.13"', PROJECT.read_text(encoding="utf-8"))

if __name__ == "__main__":
    unittest.main()
