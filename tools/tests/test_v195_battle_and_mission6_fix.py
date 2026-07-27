import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"

class V195BattleAndMission6FixTests(unittest.TestCase):
    def test_parent_ready_runs_for_every_mission(self):
        text = (PROJECT / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        block = text[text.index("func _ready() -> void:"):text.index("func _load_first_mission()")]
        self.assertIn("\tsuper._ready()", block)
        self.assertLess(block.index("\tsuper._ready()"), block.index("\tif mission_number != 6:"))
        self.assertNotIn("\t\tsuper._ready()", block)

    def test_mission6_builds_player_party_in_production_spawn(self):
        text = (PROJECT / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        block = text[text.index("func _spawn_mission_units()") : text.index("func _spawn_south()")]
        self.assertIn("_setup_player_party()", block)
        party = text[text.index("func _setup_player_party()") : text.index("func _request_kingdom_choice()")]
        for token in ["player_unit", "andrew_unit", "zeira_unit_five", "ione_unit", "reyna_unit"]:
            self.assertIn(token, party)

    def test_kingdom_leaders_receive_real_side_teams_before_choice(self):
        text = (PROJECT / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
        for token in [
            '_set_kingdom_identity(logan_unit, "south")',
            '_set_kingdom_identity(claire, "south")',
            '_set_kingdom_identity(shion, "south")',
            '_set_kingdom_identity(alden_unit, "north")',
            '_set_kingdom_identity(devlin_unit, "north")',
            '_set_kingdom_identity(barlow, "north")',
        ]:
            self.assertIn(token, text)
        self.assertIn('_refresh_kingdom_team_visual(u)', text)

    def test_smokes_do_not_mask_initialisation_failures(self):
        movement = (PROJECT / "scripts/movement_input_smoke.gd").read_text(encoding="utf-8")
        mission6 = (PROJECT / "scripts/mission6_smoke.gd").read_text(encoding="utf-8")
        startup = (PROJECT / "scripts/battle_startup_smoke.gd").read_text(encoding="utf-8")
        self.assertNotIn("fixture", movement.lower())
        self.assertNotIn("fixture", mission6.lower())
        for mission in range(1, 7):
            self.assertIn(f'{{"mission": {mission},', startup)
        self.assertIn("BATTLE_STARTUP_SMOKE_OK", startup)

    def test_workflows_are_strict_and_test_both_mission6_branches(self):
        for name in ["build-windows.yml", "release-windows.yml"]:
            workflow = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertNotIn("continue-on-error", workflow)
            self.assertIn("BattleStartupSmoke.tscn", workflow)
            self.assertIn("Mission6Smoke.tscn", workflow)
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
        section = gate[gate.index("func _create_castle_gate"):gate.index("func _spawn_mission_units")]
        self.assertNotIn("MeshInstance3D.new", section)

    def test_version(self):
        project = (PROJECT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.5"', project)

if __name__ == "__main__":
    unittest.main()
