import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class MissionReplayCoinsTests(unittest.TestCase):
    def test_mission_selector_scene_and_named_outcomes_exist(self):
        scene = (PROJECT / "scenes" / "MissionSelect.tscn").read_text(encoding="utf-8")
        script = (PROJECT / "scripts" / "mission_select.gd").read_text(encoding="utf-8")
        self.assertIn("mission_select.gd", scene)
        for text in [
            "Миссия 1 — Приграничная деревня",
            "Миссия 2 — Лес и болото: спасение Andrew",
            "Миссия 3А — Мост: остаться с Kamorge",
            "Миссия 3Б — Мост: послушать Kamorge",
        ]:
            self.assertIn(text, script)
        self.assertIn('"stay_and_fight"', script)
        self.assertIn('"seek_southern_aid"', script)

    def test_wallet_is_persistent_and_has_migration(self):
        state = (PROJECT / "scripts" / "campaign_state.gd").read_text(encoding="utf-8")
        self.assertRegex(state, r"SAVE_VERSION:\s*int\s*=\s*20")
        self.assertIn('"coins": coins', state)
        self.assertIn('"mission_reward_claimed": mission_reward_claimed', state)
        self.assertIn("func _migrate_coin_economy", state)
        self.assertIn("if loaded_version < SAVE_VERSION:", state)
        self.assertIn("save_game()", state)

    def test_rewards_are_wired_into_combat_and_completion(self):
        state = (PROJECT / "scripts" / "campaign_state.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts" / "battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn("STANDARD_ATAC_REWARD: int = 25", state)
        self.assertIn("COMMANDER_ATAC_REWARD: int = 50", state)
        self.assertIn("ELITE_ATAC_REWARD: int = 75", state)
        self.assertIn("1: 200", state)
        self.assertIn("2: 300", state)
        self.assertIn("3: 500", state)
        self.assertIn("award_atac_elimination", battle)
        self.assertIn("coin_rewarded", battle)
        self.assertIn("_award_mission_completion_once", state)

    def test_forced_branch_is_consumed_by_mission_three(self):
        state = (PROJECT / "scripts" / "campaign_state.gd").read_text(encoding="utf-8")
        mission = (PROJECT / "scripts" / "campaign_battle_v08.gd").read_text(encoding="utf-8")
        self.assertIn("func prepare_mission_for_test", state)
        self.assertIn("CampaignState.test_forced_branch", mission)
        self.assertIn('CampaignState.test_forced_branch = ""', mission)

    def test_wallet_visible_in_main_hub_and_battle(self):
        main_scene = (PROJECT / "scenes" / "Main.tscn").read_text(encoding="utf-8")
        main = (PROJECT / "scripts" / "main.gd").read_text(encoding="utf-8")
        hub = (PROJECT / "scripts" / "campaign_hub.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts" / "battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn('name="Wallet"', main_scene)
        self.assertIn("get_coin_balance", main)
        self.assertIn("Общий фонд команды", hub)
        self.assertIn("_build_coin_display", battle)


if __name__ == "__main__":
    unittest.main()
