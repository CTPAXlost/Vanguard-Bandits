import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class CastleDefenseV18Tests(unittest.TestCase):
    def test_battle_scene_uses_v18_controller(self):
        scene = (PROJECT / "scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        self.assertIn("campaign_battle_v19.gd", scene)

    def test_mission_three_movement_lock_is_released(self):
        script = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        self.assertIn("mission_three_intro_pending = false", script)
        self.assertIn("if branch_combat_active and not branch_resolution_started:", script)
        smoke = (PROJECT / "scripts/mission3_smoke.gd").read_text(encoding="utf-8")
        self.assertIn("MISSION3_MOVEMENT_UNLOCK_OK", smoke)
        self.assertIn("MISSION3_BRANCH_3A_MOVEMENT_OK", smoke)
        self.assertIn("MISSION3_BRANCH_3B_MOVEMENT_OK", smoke)
        self.assertIn("battle.call(\"_unhandled_input\", click)", smoke)

    def test_castle_defense_map_and_forces(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual(data["mission_number"], 5)
        self.assertEqual(len(data["enemy_starts"]["barbatos"]), 5)
        for key in ("faulkner", "duyere"):
            self.assertIn(key, data["enemy_starts"])
        for key in ("sadira", "franco", "halak"):
            self.assertIn(key, data["neutral_starts"])
        self.assertGreaterEqual(data["width"], 28)

    def test_new_atac_assets_are_rigged_and_normalized(self):
        skeletal = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        for slug in ("sylpheed", "korbelan"):
            self.assertIn(f'"{slug}"', skeletal)
            rig = PROJECT / "assets/atac_rigged" / slug / "rig.json"
            self.assertTrue(rig.is_file(), rig)
            rig_data = json.loads(rig.read_text(encoding="utf-8"))
            self.assertGreaterEqual(len(rig_data["parts"]), 8)
            for view in ("front", "back", "side", "three_quarter"):
                path = PROJECT / "assets/atac_views" / slug / f"{view}.png"
                self.assertTrue(path.is_file(), path)
                image = Image.open(path).convert("RGBA")
                self.assertEqual(image.getchannel("A").getextrema()[0], 0)
        self.assertIn("recommended_tactical_scale", skeletal)
        self.assertIn('get_meta("recommended_tactical_scale"', battle)

    def test_sadira_and_bodyguard_mechanics(self):
        script = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        for token in (
            "sylpheed_air_counter", "0.80 if back_attack else 0.60",
            "energy_restore_uses", "steel_armor", "0.40",
            "400", "0.45", "disabled_turns", "neutral_observer",
            "_activate_neutral_group",
        ):
            self.assertIn(token, script)
        for attack in ("sound_strike", "wind_strike", "incinerate", "guillotine"):
            self.assertIn(f'"{attack}"', catalog)
        self.assertIn('"energy": 20', catalog)
        self.assertIn('"energy": 25', catalog)
        self.assertIn('"energy": 30', catalog)
        self.assertIn('"energy": 40', catalog)

    def test_story_choice_outcomes_and_shop_unlocks(self):
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        hub = (PROJECT / "scripts/campaign_hub.gd").read_text(encoding="utf-8")
        selector = (PROJECT / "scripts/mission_select.gd").read_text(encoding="utf-8")
        shop = (PROJECT / "scripts/shop.gd").read_text(encoding="utf-8")
        for token in ("castle_defended", "castle_lost", "left_castle", "southern_route_pending"):
            self.assertIn(token, state)
        for token in ("defend_castle", "leave_castle", "Миссия 5А", "Миссия 5Б"):
            self.assertIn(token, selector)
        self.assertIn("Глава VI", hub)
        self.assertIn("Kamorge погиб", hub)
        self.assertIn("CampaignState.is_item_available", shop)
        for icon in (
            "castle_guard_blade.png", "royal_vanguard_blade.png",
            "castle_oath_amulet.png", "wind_guard_amulet.png",
            "ruby_skill_stone.png", "sapphire_skill_stone.png",
        ):
            path = PROJECT / "assets/ui/shop" / icon
            self.assertTrue(path.is_file(), path)
            self.assertGreater(path.stat().st_size, 5000)

    def test_github_workflow_has_mission5_runtime_gate(self):
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn("Mission5Smoke.tscn", workflow)
        self.assertIn("MISSION5_DEFENSE_SMOKE_OK", workflow)
        self.assertIn("MISSION5_NEUTRAL_GROUP_SMOKE_OK", workflow)
        self.assertIn("NORMALIZED_ATAC_SCALE_SMOKE_OK", workflow)


if __name__ == "__main__":
    unittest.main()
