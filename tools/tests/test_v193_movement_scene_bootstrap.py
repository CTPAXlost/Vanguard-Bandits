import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

class MovementSceneBootstrapTests(unittest.TestCase):
    def test_smoke_scene_preinstances_battle(self):
        scene = (ROOT / "project/scenes/MovementInputSmoke.tscn").read_text(encoding="utf-8")
        script = (ROOT / "project/scripts/movement_input_smoke.gd").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn('res://scenes/BattlePrototype.tscn', scene)
        self.assertIn('instance=ExtResource("2")', scene)
        self.assertIn('func _enter_tree()', script)
        self.assertNotIn('packed_scene.instantiate()', script)
        self.assertIn('--quit-after 1800', workflow)

if __name__ == "__main__":
    unittest.main()
