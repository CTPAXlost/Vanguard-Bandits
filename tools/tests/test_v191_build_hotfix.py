import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class V191BuildHotfixTests(unittest.TestCase):
    def test_mission6_zeira_variable_is_declared(self):
        text = (ROOT / "project/scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        self.assertIn("var zeira_unit_five: Node3D", text)
        self.assertIn("zeira_unit_five = _spawn_campaign_hero", text)

    def test_project_version(self):
        text = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.11"', text)

if __name__ == "__main__":
    unittest.main()
