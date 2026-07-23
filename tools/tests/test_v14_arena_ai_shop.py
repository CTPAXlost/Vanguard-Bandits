import re
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V14ArenaAIShopTests(unittest.TestCase):
    def test_save_and_arena_setting_are_persistent(self) -> None:
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        self.assertRegex(state, r"SAVE_VERSION:\s*int\s*=\s*14")
        self.assertIn("arena_battles_enabled: bool = true", state)
        self.assertIn('"arena_battles_enabled": arena_battles_enabled', state)
        self.assertIn("func toggle_arena_battles", state)

    def test_mission_one_dialogue_is_scoped_and_kamorge_is_not_duplicated(self) -> None:
        base = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        mission4 = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        self.assertIn('str(map_data.get("id", "")) == "mission_01_border_village"', base)
        self.assertRegex(mission4, re.compile(r"func _spawn_mission_four_units\(\).*?kamorge_spawned = true", re.S))
        self.assertEqual(mission4.count('player_unit = _spawn_campaign_hero(\n\t\t"kamorge"'), 1)

    def test_tactical_rendering_is_stable_and_arena_is_separate(self) -> None:
        factory = (PROJECT / "scripts/atac_factory.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        arena = (PROJECT / "scripts/battle_arena_director.gd").read_text(encoding="utf-8")
        self.assertIn('render_context == "tactical"', factory)
        self.assertIn('AtacFactory.create_atac(model_slug, "tactical")', battle)
        self.assertIn('AtacFactory.create_atac(attacker_slug, "arena")', arena)
        self.assertIn("SubViewport.UPDATE_DISABLED", arena)
        self.assertIn("SubViewport.UPDATE_ALWAYS", arena)
        self.assertIn("func play_attack", arena)
        self.assertIn("_animate_melee", arena)
        self.assertIn("_animate_projectile_or_magic", arena)

    def test_player_attacks_open_arena_and_hub_can_toggle_it(self) -> None:
        battle = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        hub = (PROJECT / "scripts/campaign_hub.gd").read_text(encoding="utf-8")
        self.assertIn("CampaignState.arena_battles_enabled", battle)
        self.assertIn("await battle_arena.play_attack", battle)
        self.assertIn("3D-арена атак", hub)
        self.assertIn("toggle_arena_battles", hub)

    def test_allied_ai_is_path_aware_and_rechecks_after_moving(self) -> None:
        battle = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for token in [
            "_ai_attack_cells",
            "_find_path_to_any",
            "reachable_path_length",
            "Re-evaluate after movement",
            "_best_ai_target_for_mode",
            'chosen_mode = "slash"',
            "await _resolve_attack(unit, attack_target, chosen_mode)",
        ]:
            self.assertIn(token, battle)


    def test_arena_has_runtime_smoke_scene(self) -> None:
        scene = (PROJECT / "scenes/ArenaSmoke.tscn").read_text(encoding="utf-8")
        script = (PROJECT / "scripts/arena_smoke.gd").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn("arena_smoke.gd", scene)
        self.assertIn("ARENA_SMOKE_OK", script)
        self.assertIn("ArenaSmoke.tscn", workflow)
        self.assertIn("arena-smoke.log", workflow)

    def test_shop_has_visible_item_art(self) -> None:
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        shop = (PROJECT / "scripts/shop.gd").read_text(encoding="utf-8")
        self.assertIn("fixed_icon_size", shop)
        self.assertIn("item_preview", shop)
        icon_names = [
            "steel_sword_i.png",
            "improved_sword_ii.png",
            "royal_sword_iii.png",
            "copper_amulet.png",
            "unity_amulet.png",
            "opal_skill_stone.png",
        ]
        for name in icon_names:
            self.assertIn(name, state)
            path = PROJECT / "assets/ui/shop" / name
            self.assertTrue(path.is_file(), path)
            image = Image.open(path).convert("RGBA")
            self.assertGreaterEqual(image.width, 192)
            self.assertGreaterEqual(image.height, 192)
            low, high = image.getchannel("A").getextrema()
            self.assertEqual(low, 0)
            self.assertEqual(high, 255)

    def test_unit_panel_is_less_likely_to_clip(self) -> None:
        scene = (PROJECT / "scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        self.assertIn("custom_minimum_size = Vector2(270, 270)", scene)
        self.assertGreaterEqual(scene.count("autowrap_mode = 2"), 2)


if __name__ == "__main__":
    unittest.main()
