import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V185CastleHotfixTests(unittest.TestCase):
    def test_gate_is_wide_and_cells_are_passable(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual(data["castle"]["gate_z"], [6, 7, 8, 9, 10, 11])
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        for wall_x in (data["castle"]["west_wall_x"], data["castle"]["east_wall_x"]):
            for x in range(wall_x - 1, wall_x + 2):
                for z in data["castle"]["gate_z"]:
                    self.assertNotIn((x, z), blocked)
        source = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        self.assertIn("deliberately completely open", source)
        self.assertNotIn("OpenGateLeafLeft", source)

    def test_neutral_observers_are_on_visible_open_field(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual(data["neutral_starts"], {
            "sadira": [8, 13], "franco": [9, 12], "halak": [9, 14]
        })
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        for cell in data["neutral_starts"].values():
            self.assertNotIn(tuple(cell), blocked)

    def test_zakov_only_attacks_allies_under_real_disorientation(self):
        source = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        base = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        self.assertIn("return await super._try_disoriented_friendly_fire(unit)", source)
        self.assertIn('var disoriented_turns: int = int(enemy.get_meta("disoriented_turns", 0))', base)
        self.assertIn("if await _try_disoriented_friendly_fire(enemy):", base)
        self.assertNotIn('unit.set_meta("friendly_fire_chance", 0.0)', source)

    def test_shop_lists_all_catalog_items(self):
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        self.assertIn("func is_item_available(item_id: String) -> bool:\n\treturn SHOP_ITEMS.has(item_id)", state)
        self.assertNotIn('requires_castle_defense', state[state.find("func is_item_available"):state.find("func get_inventory_count")])

    def test_faulkner_has_fire_rain_and_full_loadout(self):
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        for marker in ('"fire_rain"', '"label": "Град огня с неба"', '"energy": 60', '"range": 5'):
            self.assertIn(marker, catalog)
        loadout_start = catalog.index('"faulkner": [')
        loadout_end = catalog.index('],', loadout_start)
        loadout = catalog[loadout_start:loadout_end]
        for attack in ("slash", "lunge", "long_lunge", "strong_slash", "ball_lightning", "bright_bomb", "fire_rain"):
            self.assertIn(f'"{attack}"', loadout)
        self.assertIn("func _animate_fire_rain", battle)

    def test_healing_targets_are_allies_or_self_only(self):
        aura = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        mission5 = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        self.assertIn('str(ally.get_meta("team")) != "ally"', aura)
        self.assertIn("unit in [franco_unit, halak_unit]", mission5)
        self.assertNotIn('target_stats["hp"]', mission5)

    def test_rig_parts_render_without_depth_cutout(self):
        source = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn("sprite.no_depth_test = true", source)
        self.assertIn("sprite.double_sided = true", source)
        self.assertIn("sprite.custom_aabb = SAFE_AABB", source)


if __name__ == "__main__":
    unittest.main()
