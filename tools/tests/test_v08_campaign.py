from pathlib import Path
import json
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V08CampaignTests(unittest.TestCase):
    def test_battle_scene_uses_v08_controller(self) -> None:
        scene = (PROJECT / "scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        self.assertIn("campaign_battle_v18.gd", scene)

    def test_target_facing_reaction_and_upgrade_systems(self) -> None:
        script = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for marker in (
            "target_selection_active",
            "_show_attack_targets",
            "_request_facing_choice",
            "counter_slash",
            "counter_lunge",
            "reaction_back_attack",
            "auto_reflect",
            "auto_dodge_60",
            "_open_upgrade_panel",
            "_allocate_battle_stat",
        ):
            self.assertIn(marker, script)
        self.assertNotIn('tween_property(dust, "modulate:a"', script)
        self.assertNotIn(") if sequence == 1 else", script)

    def test_attack_catalog_contains_requested_attacks(self) -> None:
        script = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        for attack in (
            "strong_slash",
            "shoulder_bash",
            "tornado",
            "ball_lightning",
            "bright_bomb",
            "earthquake",
        ):
            self.assertIn(f'"{attack}"', script)
        self.assertIn('"andrew"', script)
        self.assertIn('"faulkner"', script)
        self.assertIn('"duyere"', script)

    def test_mission_three_bridge_and_armies(self) -> None:
        data = json.loads((PROJECT / "data/maps/mission_03.json").read_text(encoding="utf-8"))
        self.assertEqual(data["bridge_width_cells"], 1)
        self.assertEqual(len(data["bridge_cells"]), 2)
        self.assertEqual(len(data["faulkner_vanguard"]), 2)
        self.assertEqual(len(data["faulkner_troops"]), 4)
        self.assertEqual(len(data["duyere_troops"]), 5)
        self.assertEqual(data["story_choice"], ["seek_southern_aid", "stay_and_fight"])
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        self.assertNotIn(tuple(data["duyere_cell"]), blocked)
        self.assertNotIn(tuple(data["captain_cell"]), blocked)

    def test_new_multiview_models_are_clean_and_present(self) -> None:
        for slug in ("barbatos", "vedocorban", "solarus", "sarbelas", "einlager"):
            for view in ("front", "back", "side", "three_quarter"):
                path = PROJECT / "assets/atac_views" / slug / f"{view}.png"
                self.assertTrue(path.is_file(), path)
                image = Image.open(path).convert("RGBA")
                alpha = image.getchannel("A")
                extrema = alpha.getextrema()
                self.assertEqual(extrema[0], 0, path)
                self.assertGreater(extrema[1], 200, path)
                opaque_ratio = sum(1 for px in alpha.getdata() if px > 32) / (image.width * image.height)
                self.assertGreater(opaque_ratio, 0.025, path)
                self.assertLess(opaque_ratio, 0.80, path)

    def test_mission_three_villains_and_dialogue_exist(self) -> None:
        script = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for marker in (
            "Faulkner / Solarus",
            "Duyere / Sarbelas",
            "Captain Soldiers / Einlager",
            "Южное королевство",
            "stay_and_fight",
            "seek_southern_aid",
            "Мой отец говорил",
        ):
            self.assertIn(marker, script)

    def test_hub_launches_third_mission(self) -> None:
        hub = (PROJECT / "scripts/campaign_hub.gd").read_text(encoding="utf-8")
        self.assertIn("Начать третью миссию", hub)
        self.assertIn("_start_next_mission", hub)
        self.assertIn("CampaignState.current_mission = 3", hub)

    def test_state_persists_third_mission_branch(self) -> None:
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        for marker in ("mission_3_complete", "story_branch", "SAVE_VERSION: int = 18"):
            self.assertIn(marker, state)


if __name__ == "__main__":
    unittest.main()
