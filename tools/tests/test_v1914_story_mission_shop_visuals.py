from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
KINGDOM_ATACS = ("crimson", "rahabar", "altagrave", "snow_soldier", "ratatosk")


class V1914StoryMissionShopVisualTests(unittest.TestCase):
    def read(self, relative: str) -> str:
        return (PROJECT / relative).read_text(encoding="utf-8")

    def test_mission_six_is_visible_in_a_responsive_scrolling_selector(self) -> None:
        selector = self.read("scripts/mission_select.gd")
        self.assertIn("ScrollContainer.new()", selector)
        self.assertIn('scroll.name = "MissionScroll"', selector)
        self.assertIn('"Миссия 6А — Война королевств: поддержать Юг"', selector)
        self.assertIn('"Миссия 6Б — Война королевств: поддержать Север"', selector)
        self.assertIn('MISSION_SELECT_OK buttons=%d scroll=true', selector)
        self.assertNotIn("Vector2(1100, 980)", selector)
        hub = self.read("scripts/campaign_hub.gd")
        self.assertIn('CampaignState.current_mission = 6', hub)
        self.assertIn('CampaignState.story_branch == "stay_and_fight"', hub)

    def test_forced_replay_branch_no_longer_disables_story_dialogue(self) -> None:
        mission5 = self.read("scripts/campaign_battle_v18.gd")
        detection = mission5[
            mission5.index("func _is_headless_or_smoke_runtime") : mission5.index("func _ready")
        ]
        self.assertNotIn("test_forced_branch", detection)
        self.assertIn("await _play_mission_five_intro()", mission5)
        mission6 = self.read("scripts/campaign_battle_v19.gd")
        self.assertIn("mission_six_forced_choice", mission6)
        self.assertIn("await _play_mission_six_intro()", mission6)
        self.assertIn("await _play_mission_six_choice_dialogue()", mission6)
        for speaker in (
            '"Bastion"', '"Andrew"', '"Zeira"', '"Ione"', '"Reyna"',
            '"Logan"', '"Claire"', '"Shion"', '"Alden"', '"Devlin"', '"Barlow"',
        ):
            self.assertIn(f"_show_dialogue({speaker}", mission6)
        # The earlier chapters still contain their original branch-separating conversations.
        all_dialogue = "\n".join(
            self.read(path)
            for path in (
                "scripts/campaign_battle.gd",
                "scripts/campaign_battle_v08.gd",
                "scripts/campaign_battle_v12.gd",
                "scripts/campaign_battle_v18.gd",
                "scripts/campaign_battle_v19.gd",
            )
        )
        self.assertGreaterEqual(all_dialogue.count("await _show_dialogue"), 75)

    def test_castle_passages_are_wide_and_have_no_hidden_blockers(self) -> None:
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual([6, 7, 8, 9, 10, 11], data["castle"]["gate_z"])
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        for wall_x in (data["castle"]["west_wall_x"], data["castle"]["east_wall_x"]):
            for x in range(wall_x - 1, wall_x + 2):
                for z in data["castle"]["gate_z"]:
                    self.assertNotIn((x, z), blocked)
        battle = self.read("scripts/campaign_battle_v18.gd")
        gate_section = battle[
            battle.index("func _create_castle_gate") : battle.index("func _spawn_mission_units")
        ]
        self.assertIn("return", gate_section)
        self.assertNotIn("MeshInstance3D.new", gate_section)
        self.assertIn("func _open_castle_passages", battle)
        self.assertIn("blocked_cells.erase", battle)

    def test_shop_preloads_and_displays_all_twelve_items(self) -> None:
        shop = self.read("scripts/shop.gd")
        self.assertIn("const SHOP_ICONS: Dictionary", shop)
        self.assertEqual(12, shop.count('preload("res://assets/ui/shop/'))
        self.assertIn('"Товары и общий склад — %d позиций"', shop)
        self.assertIn("SHOP_CATALOG_OK items=%d", shop)
        self.assertNotIn("доступных предметов нет", shop.lower())
        state = self.read("scripts/campaign_state.gd")
        shop_items = state[state.index("const SHOP_ITEMS") : state.index("const UNIQUE_ATACS")]
        self.assertEqual(12, shop_items.count('"icon": "res://assets/ui/shop/'))

    def test_kingdom_atacs_use_complete_transparent_full_body_views(self) -> None:
        factory = self.read("scripts/atac_factory.gd")
        multiview = self.read("scripts/multiview_atac.gd")
        self.assertIn("FULL_BODY_TACTICAL_SLUGS", factory)
        self.assertIn("normalized in FULL_BODY_TACTICAL_SLUGS", factory)
        for slug in KINGDOM_ATACS:
            self.assertIn(f'"{slug}"', factory)
            self.assertIn(f'"{slug}"', multiview)
            for view in ("front", "back", "side", "three_quarter"):
                path = PROJECT / "assets/atac_views" / slug / f"{view}.png"
                self.assertTrue(path.is_file(), path)
                with Image.open(path) as image:
                    rgba = image.convert("RGBA")
                    self.assertEqual((720, 1024), rgba.size)
                    low, high = rgba.getchannel("A").getextrema()
                    self.assertEqual(0, low)
                    self.assertEqual(255, high)

    def test_requested_mission_six_loadouts_and_energy_costs_exist(self) -> None:
        catalog = self.read("scripts/combat_catalog.gd")
        for marker in (
            '"evil_heart": {"label":"Злое сердце","fatigue":0,"energy":45',
            '"frost": {"label":"Мороз","fatigue":0,"energy":30',
            '"storm_vortex": {"label":"Вихрь бури","fatigue":0,"energy":80',
            '"shot": {"label":"Выстрел","fatigue":0,"energy":5,"range":3',
            '"precise_shot": {"label":"Точный выстрел","fatigue":0,"energy":15,"range":4',
            '"rocket_shot": {"label":"Выстрел ракеты","fatigue":0,"energy":30,"range":3',
            '"punch": {"label":"Удар кулаком","fatigue":0,"energy":0,"range":1',
            '"devlin_combo": {"label":"Комбо","fatigue":0,"energy":50',
        ):
            self.assertIn(marker, catalog)
        mission6 = self.read("scripts/campaign_battle_v19.gd")
        for marker in (
            'set_meta("double_turn", true)', 'set_meta("damage_magic_uses", 2)',
            'set_meta("magic_immune", true)', 'set_meta("clone_uses", 1)',
            'full_body_rigs != 18',
        ):
            if marker == 'full_body_rigs != 18':
                self.assertIn(marker, self.read("scripts/mission6_smoke.gd"))
            else:
                self.assertIn(marker, mission6)

    def test_southern_reinforcement_is_checked_before_victory_can_finish(self):
        battle = (ROOT / "project/scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        resolve_start = battle.index("func _resolve_attack")
        retaliation_start = battle.index("func _try_alden_iceberg_retaliation")
        resolve_body = battle[resolve_start:retaliation_start]
        self.assertIn("if mission_number == 6 and not southern_reinforcement_spawned", resolve_body)
        self.assertIn("_check_south_reinforcement()", resolve_body)


if __name__ == "__main__":
    unittest.main()
