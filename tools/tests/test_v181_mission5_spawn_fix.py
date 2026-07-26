from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Mission5SpawnFixTests(unittest.TestCase):
    def test_mission5_uses_existing_balance_profiles(self):
        script = (ROOT / "project/scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        self.assertIn('"bastion_alba", BASTION_PORTRAIT_V12', script)
        self.assertIn('"andrew_vedocorban", ANDREW_PORTRAIT_V12', script)

    def test_stats_and_hp_bar_have_safe_fallbacks(self):
        script = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn('"bastion": "bastion_alba"', script)
        self.assertIn('"andrew": "andrew_vedocorban"', script)
        self.assertIn('stats.get("hp", stats.get("max_hp", 1))', script)
        self.assertIn('Missing balance profile', script)

    def test_skeleton_does_not_use_global_position_before_tree(self):
        script = (ROOT / "project/scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn('if is_inside_tree() and model_root.is_inside_tree():', script)
        self.assertIn('model_root.position = Vector3.ZERO', script)


    def test_neutral_balance_profiles_exist(self):
        import json
        balance = json.loads((ROOT / "project/data/balance/level_01_units.json").read_text(encoding="utf-8"))
        for profile in ("sadira_sylpheed", "franco_korbelan", "halak_korbelan"):
            self.assertIn(profile, balance)
            self.assertGreater(balance[profile]["hp"], 1)

    def test_project_version(self):
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.8.2"', project)


if __name__ == "__main__":
    unittest.main()
