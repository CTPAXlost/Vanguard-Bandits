from pathlib import Path
import json
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V10BridgePartisanTests(unittest.TestCase):
    def test_new_character_and_atac_assets(self) -> None:
        for portrait in ("ione.png", "reyna.png", "zeira.png"):
            path = PROJECT / "assets/ui/portraits" / portrait
            self.assertTrue(path.is_file(), path)
            self.assertGreater(path.stat().st_size, 100_000)
        for slug in ("amphisia", "haurol", "toreadore"):
            for view in ("front", "side", "back", "three_quarter"):
                path = PROJECT / "assets/atac_views" / slug / f"{view}.png"
                self.assertTrue(path.is_file(), path)
                image = Image.open(path).convert("RGBA")
                low, high = image.getchannel("A").getextrema()
                self.assertEqual(low, 0, path)
                self.assertEqual(high, 255, path)

    def test_state_version_levels_and_unlocks(self) -> None:
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        for marker in (
            "SAVE_VERSION: int = 20",
            '"ione"',
            '"reyna"',
            '"zeira"',
            '"amphisia"',
            '"haurol"',
            '"toreadore"',
            "partisans_joined",
            "func complete_mission",
        ):
            self.assertIn(marker, state)
        self.assertIn('"Ione", "res://assets/ui/portraits/ione.png", 8', state)
        self.assertIn('"Reyna", "res://assets/ui/portraits/reyna.png", 10', state)
        self.assertIn('"Zeira", "res://assets/ui/portraits/zeira.png", 18', state)

    def test_requested_attacks_have_exact_costs_and_effects(self) -> None:
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        for marker in (
            '"spear_throw"',
            '"ice_rain"',
            '"ultrasound"',
            '"slide"',
            '"freeze_chance": 0.30',
            '"freeze_turns": 2',
            '"friendly_fire_chance": 0.50',
            '"energy": 80',
            '"range": 5',
            '"range_mode": "up_to"',
        ):
            self.assertIn(marker, catalog)
        self.assertRegex(catalog, r'"spear_throw": \{[\s\S]*?"energy": 25[\s\S]*?"range": 5')
        self.assertRegex(catalog, r'"ice_rain": \{[\s\S]*?"energy": 30[\s\S]*?"freeze_chance": 0\.30')
        self.assertRegex(catalog, r'"ultrasound": \{[\s\S]*?"energy": 30[\s\S]*?"friendly_fire_chance": 0\.50')

    def test_corrected_branch_flow_and_unique_mechanics(self) -> None:
        battle = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for marker in (
            "CAPTURE_SURVIVAL_ROUNDS: int = 3",
            'branch_combat_mode = "capture_no_help"',
            'branch_combat_mode = "partisan_rescue"',
            "_play_faulkner_kamorge_duel",
            "_animate_kamorge_river_jump",
            "_spawn_partisan_reinforcements",
            "_play_forced_capture_outro",
            "toreadore_rear_kick",
            "rear_kick_multiplier",
            "rear_kick_distance",
            "max_move_actions",
            "energy_restore_uses",
            "_animate_spear_throw",
            "_animate_ice_rain",
            "_animate_ultrasound",
            "_animate_slide",
            "_attempt_knockback_distance",
            "_try_disoriented_friendly_fire",
        ):
            self.assertIn(marker, battle)
        self.assertIn("прыгает в реку", battle)
        self.assertIn("Партизан здесь нет", battle)
        self.assertIn("Ione, Reyna и Zeira присоединились", battle)

    def test_mission_three_contains_branch_parameters(self) -> None:
        data = json.loads((PROJECT / "data/maps/mission_03.json").read_text(encoding="utf-8"))
        self.assertEqual(data["status"], "campaign_v10_corrected_bridge_branches")
        self.assertEqual(data["capture_survival_rounds"], 3)
        self.assertEqual(data["partisan_spawns"]["ione"], [21, 3])
        self.assertEqual(data["partisan_spawns"]["reyna"], [20, 4])
        self.assertEqual(data["partisan_spawns"]["zeira"], [19, 4])
        blocked = {tuple(value) for value in data["blocked_cells"]}
        for cell in data["partisan_spawns"].values():
            self.assertNotIn(tuple(cell), blocked)

    def test_branch_specific_story_and_hub(self) -> None:
        story = (PROJECT / "scripts/story_chapter.gd").read_text(encoding="utf-8")
        hub = (PROJECT / "scripts/campaign_hub.gd").read_text(encoding="utf-8")
        for marker in (
            "Глава IV — Лесной лагерь партизан",
            "Глава IV — Имперская тюрьма",
            "Ione",
            "Reyna",
            "Zeira",
            "прыгнул в реку",
        ):
            self.assertIn(marker, story)
        self.assertIn("ЛЕСНОЙ ЛАГЕРЬ ПАРТИЗАН", hub)
        self.assertIn("Bastion и Andrew находятся в плену", hub)
        self.assertNotIn("Начать миссию Kamorge — Eigol", hub)

    def test_balance_profiles_match_requested_levels(self) -> None:
        data = json.loads((PROJECT / "data/balance/level_01_units.json").read_text(encoding="utf-8"))
        self.assertEqual(data["ione_amphisia"]["level"], 8)
        self.assertEqual(data["reyna_haurol"]["level"], 10)
        self.assertEqual(data["zeira_toreadore"]["level"], 18)
        self.assertEqual(data["zeira_toreadore"]["move_range"], 15)
        self.assertEqual(data["reyna_haurol"]["max_energy"], 100)
        self.assertEqual(data["zeira_toreadore"]["max_energy"], 100)


if __name__ == "__main__":
    unittest.main()
