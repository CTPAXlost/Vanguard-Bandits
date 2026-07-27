from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def test_release_version_is_197() -> None:
    assert 'config/version="1.9.11"' in read("project/project.godot")


def test_mission_six_balance_profiles_are_real_and_complete() -> None:
    balance = json.loads(
        (PROJECT / "data/balance/level_01_units.json").read_text(encoding="utf-8")
    )
    expected = {
        "logan_crimson": 25,
        "claire_rahabar": 15,
        "shion_rahabar": 22,
        "nordilian_rahabar": 10,
        "alden_altagrave": 24,
        "devlin_snow_soldier": 19,
        "barlow_ratatosk": 14,
        "matisse_ratatosk": 10,
    }
    required_fields = {
        "level",
        "hp",
        "max_hp",
        "strength",
        "agility",
        "defense",
        "magic",
        "attack_skill",
        "weapon_power",
        "move_range",
        "fatigue",
        "max_fatigue",
        "energy",
        "max_energy",
        "atac_name",
    }
    for profile, level in expected.items():
        assert profile in balance, profile
        stats = balance[profile]
        assert required_fields <= stats.keys(), profile
        assert stats["level"] == level, profile
        assert stats["hp"] == stats["max_hp"] > 1, profile
        assert stats["energy"] == stats["max_energy"] == 100, profile


def test_mission_six_registers_party_during_normal_spawn_lifecycle() -> None:
    script = read("project/scripts/campaign_battle_v19.gd")
    spawn = script[
        script.index("func _spawn_mission_units() -> void:") :
        script.index("func _spawn_south() -> void:")
    ]
    assert "_spawn_south()" in spawn
    assert "_spawn_north()" in spawn
    assert "_setup_player_party()" in spawn
    assert spawn.index("_spawn_north()") < spawn.index("_setup_player_party()")

    party = script[
        script.index("func _setup_player_party() -> void:") :
        script.index("func _request_kingdom_choice() -> void:")
    ]
    for field in (
        "player_unit",
        "andrew_unit",
        "zeira_unit_five",
        "ione_unit",
        "reyna_unit",
    ):
        assert field in party
    assert "player_party.size() != 5" in party


def test_kingdom_leaders_are_ai_and_start_on_their_own_sides() -> None:
    script = read("project/scripts/campaign_battle_v19.gd")
    for expression in (
        '_prepare_kingdom_ai_unit(logan_unit, "south")',
        '_prepare_kingdom_ai_unit(claire, "south")',
        '_prepare_kingdom_ai_unit(shion, "south")',
        '_prepare_kingdom_ai_unit(alden_unit, "north")',
        '_prepare_kingdom_ai_unit(devlin_unit, "north")',
        '_prepare_kingdom_ai_unit(barlow, "north")',
    ):
        assert expression in script
    helper = script[
        script.index("func _prepare_kingdom_ai_unit") :
        script.index("func _set_mission_six_combat_team")
    ]
    assert 'unit.set_meta("player", false)' in helper
    assert 'unit.set_meta("team", staging_team)' in helper


def test_choice_switches_every_kingdom_unit_and_visual_direction() -> None:
    script = read("project/scripts/campaign_battle_v19.gd")
    choice = script[
        script.index("func _apply_kingdom_choice") :
        script.index("func _begin_player_turn")
    ]
    assert '_set_mission_six_combat_team(u, "ally" if kingdom_choice == "south" else "enemy")' in choice
    assert '_set_mission_six_combat_team(u, "ally" if kingdom_choice == "north" else "enemy")' in choice
    helper = script[
        script.index("func _set_mission_six_combat_team") :
        script.index("func _setup_player_party")
    ]
    assert 'unit.set_meta("player", false)' in helper
    assert 'visual.rotation_degrees.y = 180.0 if team == "ally" else 0.0' in helper
    assert 'ring.material_override = ring_material' in helper


def test_runtime_smokes_block_empty_party_and_missing_profiles() -> None:
    boot = read("project/scripts/mission_boot_smoke.gd")
    mission6 = read("project/scripts/mission6_smoke.gd")
    assert "(party_value as Array).size() != 5" in boot
    assert "mission six player party must contain exactly five heroes" in mission6
    assert "kingdom leaders must be AI-controlled" in mission6
    assert 'str(battle.get("kingdom_choice")) != branch' in mission6
    for workflow in (
        ".github/workflows/build-windows.yml",
        ".github/workflows/release-windows.yml",
    ):
        text = read(workflow)
        assert "continue-on-error" not in text
        assert "Missing balance profile" in text
        assert "Mission VI player party is incomplete" in text


def test_no_mission_six_spawn_profile_is_absent_from_balance() -> None:
    script = read("project/scripts/campaign_battle_v19.gd")
    balance = json.loads(
        (PROJECT / "data/balance/level_01_units.json").read_text(encoding="utf-8")
    )
    expected = {
        "logan_crimson",
        "claire_rahabar",
        "shion_rahabar",
        "nordilian_rahabar",
        "alden_altagrave",
        "devlin_snow_soldier",
        "barlow_ratatosk",
        "matisse_ratatosk",
    }
    for profile in expected:
        assert f'"{profile}"' in script, profile
    assert expected <= balance.keys()


def load_tests(
    loader: unittest.TestLoader, tests: unittest.TestSuite, pattern: str | None
) -> unittest.TestSuite:
    suite = unittest.TestSuite()
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            suite.addTest(unittest.FunctionTestCase(value, description=name))
    return suite
