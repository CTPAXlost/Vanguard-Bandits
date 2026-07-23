import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class CampaignV07Tests(unittest.TestCase):
    def test_enemies_always_use_barbatos(self) -> None:
        for mission_name in ("mission_01.json", "mission_02.json"):
            data = json.loads((ROOT / "project/data/maps" / mission_name).read_text(encoding="utf-8"))
            groups = list(data.get("enemies", [])) + list(data.get("reinforcements", []))
            self.assertTrue(groups)
            self.assertTrue(all(unit["atac"] == "barbatos" for unit in groups))
        battle = (ROOT / "project/scripts/campaign_battle.gd").read_text(encoding="utf-8")
        self.assertIn('"barbatos",', battle)
        self.assertIn('unit.set_meta("model_slug", "barbatos")', battle)

    def test_second_mission_content(self) -> None:
        data = json.loads((ROOT / "project/data/maps/mission_02.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(data["width"], 18)
        self.assertGreaterEqual(data["height"], 15)
        self.assertEqual(len(data["enemies"]), 5)
        self.assertEqual(len(data["reinforcements"]), 6)
        self.assertTrue(all(3 <= int(unit["level"]) <= 5 for unit in data["enemies"] + data["reinforcements"]))
        self.assertGreaterEqual(len(data["swamp_cells"]), 12)
        self.assertGreaterEqual(len(data["trees"]), 10)

    def test_campaign_assets_and_atacs(self) -> None:
        for slug in ("barbatos", "cador", "vedocorban"):
            for view in ("front", "side", "back", "three_quarter"):
                self.assertTrue((ROOT / f"project/assets/atac_views/{slug}/{view}.png").is_file())
        for portrait in ("andrew.png", "cador.png", "imperial_soldier.png"):
            self.assertTrue((ROOT / "project/assets/ui/portraits" / portrait).is_file())

    def test_experience_level_points_and_atac_swap(self) -> None:
        state = (ROOT / "project/scripts/campaign_state.gd").read_text(encoding="utf-8")
        for marker in (
            "func award_experience",
            'data["stat_points"] = int(data.get("stat_points", 0)) + 3',
            "func allocate_stat",
            "func assign_atac",
            '"hp_per_level"',
            "func apply_character_progress",
        ):
            self.assertIn(marker, state)

    def test_story_sequences_and_reinforcement_trigger(self) -> None:
        battle = (ROOT / "project/scripts/campaign_battle.gd").read_text(encoding="utf-8")
        required = (
            "Это было безрассудно и слишком опасно!",
            "Прости отец, хорошо.",
            "Хммм... Я прослежу, чтобы никто не дошёл до конца.",
            "func _show_cador_cameo",
            "defeated_enemy_count >= 2",
            "func _spawn_mission_two_reinforcements",
            "Andrew",
            "Vedocorban",
        )
        for marker in required:
            self.assertIn(marker, battle)

    def test_effects_and_xp_are_visible(self) -> None:
        battle = (ROOT / "project/scripts/campaign_battle.gd").read_text(encoding="utf-8")
        for marker in (
            "func _spawn_attack_burst",
            "func _screen_flash",
            "func _spawn_lightning_chain",
            "func _spawn_experience_label",
            "func _spawn_level_up_effect",
            "ENERGY_BALL_LIGHTNING",
        ):
            self.assertIn(marker, battle)

    def test_hub_has_save_locked_store_progression_and_swap(self) -> None:
        hub = (ROOT / "project/scripts/campaign_hub.gd").read_text(encoding="utf-8")
        for marker in (
            "Сохранить достижение",
            "Общий магазин",
            "Персонажи и ATAC",
            "CampaignState.assign_atac",
            "CampaignState.allocate_stat",
            "Начать вторую миссию",
        ):
            self.assertIn(marker, hub)


if __name__ == "__main__":
    unittest.main()
