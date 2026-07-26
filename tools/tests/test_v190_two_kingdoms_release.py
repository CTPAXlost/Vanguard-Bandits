import unittest
from pathlib import Path
import json

P = Path(__file__).resolve().parents[2] / "project"


def test_all_new_atacs_use_skeletal_renderer():
    text = (P / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
    for slug in ["crimson", "rahabar", "altagrave", "snow_soldier", "ratatosk"]:
        assert f'"{slug}"' in text
        rig = json.loads((P / "assets/atac_rigged" / slug / "rig.json").read_text(encoding="utf-8"))
        assert len(rig["parts"]) >= 10


def test_mission6_runtime_contract_exists():
    assert (P / "scenes/Mission6Smoke.tscn").exists()
    smoke = (P / "scripts/mission6_smoke.gd").read_text(encoding="utf-8")
    for token in ["MISSION6_%s_BRANCH_OK", "MISSION6_SMOKE_OK"]:
        assert token in smoke


def test_open_castle_has_no_gate_geometry_or_blockers():
    battle = (P / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
    section = battle[battle.index("func _create_castle_gate"):battle.index("func _spawn_mission_units")]
    assert "return" in section
    assert "MeshInstance3D.new" not in section
    mission = json.loads((P / "data/maps/mission_05.json").read_text(encoding="utf-8"))
    blocked = {tuple(cell) for cell in mission["blocked_cells"]}
    for x in (10, 22):
        for z in (7, 8, 9, 10):
            assert (x, z) not in blocked


def test_shop_and_mission6_progression():
    state = (P / "scripts/campaign_state.gd").read_text(encoding="utf-8")
    assert "clampi(mission_id, 1, 6)" in state
    assert "current_mission = 6" in state
    assert "6: 1500" in state
    shop = state[state.index("func is_shop_available"):state.index("func get_inventory_count")]
    assert "return true" in shop


def test_requested_kingdom_abilities_are_implemented():
    script = (P / "scripts/campaign_battle_v19.gd").read_text(encoding="utf-8")
    for token in ["double_turn", "damage_magic_uses", "logan_damage_boost", "magic_immune", "alden_iceberg", "clone_uses", "devlin_combo"]:
        assert token in script


def load_tests(loader: unittest.TestLoader, tests: unittest.TestSuite, pattern: str | None) -> unittest.TestSuite:
    suite = unittest.TestSuite()
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            suite.addTest(unittest.FunctionTestCase(value, description=name))
    return suite
