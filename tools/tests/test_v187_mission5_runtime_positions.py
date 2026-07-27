import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V187Mission5RuntimePositionTests(unittest.TestCase):
    def test_runtime_smoke_matches_current_neutral_positions(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        smoke = (PROJECT / "scripts/mission5_smoke.gd").read_text(encoding="utf-8")
        for key, value in data["neutral_starts"].items():
            marker = f"Vector2i({value[0]}, {value[1]})"
            self.assertIn(marker, smoke, f"{key} runtime position is stale")
        self.assertIn("sadira=%s franco=%s halak=%s", smoke)

    def test_runtime_gate_checks_current_four_cell_opening(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual(data["castle"]["gate_z"], [6, 7, 8, 9, 10, 11])
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        for wall_x in (data["castle"]["west_wall_x"], data["castle"]["east_wall_x"]):
            for x in range(wall_x - 1, wall_x + 2):
                for z in data["castle"]["gate_z"]:
                    self.assertNotIn((x, z), blocked)


if __name__ == "__main__":
    unittest.main()
