import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V195BattleAndMission6FixTests(unittest.TestCase):
    def test_parent_ready_runs_for_every_campaign_layer(self):
        for filename in (
            "campaign_battle.gd",
            "campaign_battle_v08.gd",
            "campaign_battle_v18.gd",
            "campaign_battle_v19.gd",
        ):
            text = (PROJECT / "scripts" / filename).read_text(encoding="utf-8")
            start = text.index("func _ready() -> void:")
            end = text.find("\nfunc ", start + 1)
            block = text[start : end if end != -1 else None]
            self.assertIn("\tawait super._ready()", block, filename)

    def test_base_battle_reports_real_initialisation_without_subclass_member(self):
        text = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        block = text[text.index("battle_initialized =") : text.index("_begin_player_turn()", text.index("battle_initialized ="))]
        self.assertIn("CampaignState.current_mission", block)
        self.assertIn("BATTLE_READY_OK", block)
        self.assertIn("BATTLE_READY_FAILED", block)
        self.assertNotIn("mission_number", block)

    def test_mission6_builds_exact_player_party_in_production_spawn(self):
        text = (PROJECT / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        block = text[text.index("func _spawn_mission_units()") : text.index("func _spawn_south()")]
        self.assertIn("_setup_player_party()", block)
        party = text[text.index("func _setup_player_party()") : text.index("func _request_kingdom_choice()")]
        for token in ["player_unit", "andrew_unit", "zeira_unit_five", "ione_unit", "reyna_unit"]:
            self.assertIn(token, party)
        self.assertIn("player_party.size() != 5", party)

    def test_kingdom_leaders_are_ai_before_choice(self):
        text = (PROJECT / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        for token in [
            '_prepare_kingdom_ai_unit(logan_unit, "south")',
            '_prepare_kingdom_ai_unit(claire, "south")',
            '_prepare_kingdom_ai_unit(shion, "south")',
            '_prepare_kingdom_ai_unit(alden_unit, "north")',
            '_prepare_kingdom_ai_unit(devlin_unit, "north")',
            '_prepare_kingdom_ai_unit(barlow, "north")',
        ]:
            self.assertIn(token, text)
        helper = text[text.index("func _prepare_kingdom_ai_unit") : text.index("func _set_mission_six_combat_team")]
        self.assertIn('unit.set_meta("player", false)', helper)
        self.assertIn('unit.set_meta("team", staging_team)', helper)

    def test_smokes_use_normal_scene_lifecycle_and_do_not_mask_failures(self):
        movement_scene = (PROJECT / "scenes/MovementInputSmoke.tscn").read_text(encoding="utf-8")
        boot_scene = (PROJECT / "scenes/MissionBootSmoke.tscn").read_text(encoding="utf-8")
        movement = (PROJECT / "scripts/movement_input_smoke.gd").read_text(encoding="utf-8")
        boot = (PROJECT / "scripts/mission_boot_smoke.gd").read_text(encoding="utf-8")
        self.assertIn('path="res://scenes/BattlePrototype.tscn"', movement_scene)
        self.assertIn('path="res://scenes/BattlePrototype.tscn"', boot_scene)
        for forbidden in ("_build_environment()", "_load_first_mission()", "_spawn_mission_units()", "_setup_player_party()"):
            self.assertNotIn(forbidden, movement)
            self.assertNotIn(forbidden, boot)
        self.assertIn("battle_initialized", boot)
        self.assertIn("MISSION_BOOT_SMOKE_OK", boot)

    def test_workflows_are_strict_and_cover_all_branches(self):
        required = (
            '"1:"', '"2:"', '"3:stay_and_fight"', '"3:seek_southern_aid"',
            '"4:seek_southern_aid"', '"5:defend_castle"', '"6:south"', '"6:north"',
        )
        for name in ["build-windows.yml", "release-windows.yml"]:
            workflow = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertNotIn("continue-on-error", workflow)
            self.assertNotIn("script_chain_smoke.gd", workflow)
            self.assertIn("MissionBootSmoke.tscn", workflow)
            for spec in required:
                self.assertIn(spec, workflow)
            self.assertIn("MISSION6_SOUTH_BRANCH_OK", workflow)
            self.assertIn("MISSION6_NORTH_BRANCH_OK", workflow)
            self.assertIn("SHOP_CATALOG_OK items=12", workflow)

    def test_shop_catalog_and_open_castle_are_preserved(self):
        shop = (PROJECT / "scripts/shop.gd").read_text(encoding="utf-8")
        self.assertIn("catalog_ids.sort()", shop)
        self.assertIn("SHOP_CATALOG_OK", shop)
        self.assertNotIn("if not CampaignState.is_item_available", shop)
        mission = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        blocked = {tuple(cell) for cell in mission["blocked_cells"]}
        for x in (10, 22):
            for z in (7, 8, 9, 10):
                self.assertNotIn((x, z), blocked)
        gate = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        section = gate[gate.index("func _create_castle_gate") : gate.index("func _spawn_mission_units")]
        self.assertNotIn("MeshInstance3D.new", section)

    def test_version(self):
        project = (PROJECT / "project.godot").read_text(encoding="utf-8")
        presets = (PROJECT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.14"', project)
        self.assertEqual(presets.count('application/file_version="1.9.14.0"'), 2)
        self.assertEqual(presets.count('application/product_version="1.9.14.0"'), 2)


if __name__ == "__main__":
    unittest.main()
