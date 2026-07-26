from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class V183ZakovWaveRuntimeFixTests(unittest.TestCase):
    def test_wave_uses_fixed_requested_counts(self):
        source = (ROOT / "project/scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        self.assertIn("for index: int in range(2):", source)
        self.assertIn("for index: int in range(3):", source)
        self.assertIn('reinforcement_role", "zakov_commander"', source)
        self.assertIn('reinforcement_role", "zakov_captain"', source)
        self.assertIn('reinforcement_role", "zakov_barbatos"', source)

    def test_smoke_checks_roles_and_tracked_arrays(self):
        source = (ROOT / "project/scripts/mission5_smoke.gd").read_text(encoding="utf-8")
        self.assertIn('reinforcement_role == "zakov_commander"', source)
        self.assertIn('battle.get("zakov_captains")', source)
        self.assertIn('battle.get("zakov_barbatos")', source)
        self.assertIn("commander=%s captains=%d/%d barbatos=%d/%d", source)

    def test_failure_artifact_contains_mission5_log(self):
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn("mission5-smoke.log", workflow)
        self.assertIn("movement-input-smoke.log", workflow)

    def test_project_version(self):
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.4"', project)


if __name__ == "__main__":
    unittest.main()
