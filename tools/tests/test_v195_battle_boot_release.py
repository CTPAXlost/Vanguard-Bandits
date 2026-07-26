from __future__ import annotations

import unittest

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
SCRIPTS = PROJECT / "scripts"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def test_release_and_save_versions_are_current() -> None:
    project = read("project/project.godot")
    state = read("project/scripts/campaign_state.gd")
    assert 'config/version="1.9.6"' in project
    assert "const SAVE_VERSION: int = 20" in state


def test_every_campaign_ready_layer_awaits_parent_boot() -> None:
    for filename in (
        "campaign_battle.gd",
        "campaign_battle_v08.gd",
        "campaign_battle_v18.gd",
        "campaign_battle_v19.gd",
    ):
        text = (SCRIPTS / filename).read_text(encoding="utf-8")
        ready_start = text.index("func _ready() -> void:")
        next_func = text.find("\nfunc ", ready_start + 1)
        ready_body = text[ready_start : next_func if next_func != -1 else None]
        assert "await super._ready()" in ready_body, filename
        assert "\n\tawait super._ready()" in ready_body, (
            f"{filename} must call its parent from the function body, not only "
            "inside a mission-specific nested block"
        )


def test_v19_parent_boot_runs_before_mission_specific_exit() -> None:
    text = read("project/scripts/campaign_battle_v19.gd")
    parent = text.index("\n\tawait super._ready()")
    mission_exit = text.index("\n\tif mission_number != 6:", parent)
    assert parent < mission_exit
    # Regression for 1.9.4: the parent call was nested under this condition.
    bad_pattern = re.compile(
        r"if CampaignState\.current_mission == 6:\n(?:\t\t.*\n)*\t\tawait super\._ready\(\)"
    )
    assert not bad_pattern.search(text)


def test_smokes_do_not_rebuild_production_scene_manually() -> None:
    forbidden = (
        "_build_environment()",
        "_load_first_mission()",
        "_spawn_mission_units()",
        "_setup_player_party()",
        "_begin_player_turn()",
        '_animate_path',
    )
    for relative in (
        "project/scripts/movement_input_smoke.gd",
        "project/scripts/mission6_smoke.gd",
    ):
        text = read(relative)
        for token in forbidden:
            assert token not in text, f"{relative} still masks scene boot with {token}"


def test_blocking_normal_boot_matrix_covers_all_missions_and_both_choices() -> None:
    assert (PROJECT / "scenes/MissionBootSmoke.tscn").exists()
    smoke = read("project/scripts/mission_boot_smoke.gd")
    assert "MISSION_BOOT_SMOKE_OK" in smoke
    assert 'get_node_or_null("BattlePrototype")' in smoke
    for workflow in (
        ".github/workflows/build-windows.yml",
        ".github/workflows/release-windows.yml",
    ):
        text = read(workflow)
        assert "continue-on-error" not in text
        assert "MissionBootSmoke.tscn" in text
        for spec in (
            '"1:"',
            '"2:"',
            '"3:stay_and_fight"',
            '"3:seek_southern_aid"',
            '"4:seek_southern_aid"',
            '"5:defend_castle"',
            '"6:south"',
            '"6:north"',
        ):
            assert spec in text, f"{workflow} misses {spec}"
        assert "--import" in text
        assert "--export-release" in text


def test_mission_six_is_exclusive_to_kamorge_death_branch() -> None:
    state = read("project/scripts/campaign_state.gd")
    hub = read("project/scripts/campaign_hub.gd")
    mission6 = read("project/scripts/campaign_battle_v19.gd")
    stay = state[state.index('elif story_branch == "stay_and_fight"') :]
    assert "current_mission = 6" in stay
    mission5 = state[state.index("elif mission_id == 5:") : state.index("elif mission_id == 6:")]
    assert "current_mission = 5" in mission5
    assert "current_mission = 6" not in mission5
    start_next = hub[hub.index("func _start_next_mission") : hub.index("func _open_shop")]
    assert "if CampaignState.mission_5_complete:" in start_next
    mission5_stop = start_next[
        start_next.index("if CampaignState.mission_5_complete:") :
        start_next.index("if CampaignState.mission_4_complete:")
    ]
    assert "return" in mission5_stop
    assert "current_mission = 6" not in mission5_stop
    assert "CampaignState.kamorge_alive" in mission6
    assert 'CampaignState.test_forced_branch not in ["south", "north"]' in mission6


def test_mission_six_runtime_contract_and_save_persistence() -> None:
    smoke = read("project/scripts/mission6_smoke.gd")
    assert 'await _check_branch("south")' in smoke
    assert 'await _check_branch("north")' in smoke
    assert "first_wave_size + 6" in smoke
    assert "CampaignState.complete_mission(6, branch)" in smoke
    assert "CampaignState.load_game()" in smoke
    assert "MISSION6_SAVE_%s_OK" in smoke


def test_requested_combat_rules_are_registered() -> None:
    catalog = read("project/scripts/combat_catalog.gd")
    v18 = read("project/scripts/campaign_battle_v18.gd")
    v19 = read("project/scripts/campaign_battle_v19.gd")
    faulkner_match = re.search(r'"faulkner": \[(.*?)\],', catalog, re.S)
    assert faulkner_match
    for attack in (
        "slash",
        "lunge",
        "long_lunge",
        "strong_slash",
        "ball_lightning",
        "bright_bomb",
        "fire_rain",
    ):
        assert f'"{attack}"' in faulkner_match.group(1)
    fire_rain = catalog[catalog.index('"fire_rain": {') :]
    assert '"energy": 60' in fire_rain[:500]
    assert "return await super._try_disoriented_friendly_fire(unit)" in v18
    assert "CombatCatalog.is_magic(mode)" in v19
    assert '"iceberg"' in catalog
    assert "func _apply_alden_aura() -> void:" in v19
    aura = v19[v19.index("func _apply_alden_aura") : v19.index("func _check_south_reinforcement")]
    assert "+ 50" in aura
    assert "+ 30" in aura
    ai_turn = v19[v19.index("func _run_smart_ai_turn") : v19.index("func _first_free_adjacent_cell")]
    assert "if unit == alden_unit:" in ai_turn
    assert "_apply_alden_aura()" in ai_turn


def test_shop_catalog_icons_and_mission_maps_are_complete() -> None:
    state = read("project/scripts/campaign_state.gd")
    assert "func is_shop_available()" in state
    availability = state[state.index("func is_shop_available") : state.index("func get_inventory_count")]
    assert "return true" in availability
    icon_paths = sorted(set(re.findall(r'"icon": "(res://[^"]+)"', state)))
    assert len(icon_paths) >= 12
    for res_path in icon_paths:
        assert (PROJECT / res_path.removeprefix("res://")).is_file(), res_path
    for mission_id in range(1, 7):
        path = PROJECT / f"data/maps/mission_{mission_id:02d}.json"
        assert path.is_file()
        parsed = json.loads(path.read_text(encoding="utf-8"))
        assert isinstance(parsed, dict) and parsed


def test_critical_scene_and_script_references_exist() -> None:
    battle_scene = read("project/scenes/BattlePrototype.tscn")
    assert 'res://scripts/campaign_battle_v19.gd' in battle_scene
    assert (PROJECT / "scripts/campaign_battle_v19.gd").is_file()
    for relative in (
        "project/scenes/Main.tscn",
        "project/scenes/CampaignHub.tscn",
        "project/scenes/MissionSelect.tscn",
        "project/scenes/BattlePrototype.tscn",
        "project/scenes/Shop.tscn",
    ):
        assert (ROOT / relative).is_file()


def load_tests(loader: unittest.TestLoader, tests: unittest.TestSuite, pattern: str | None) -> unittest.TestSuite:
    suite = unittest.TestSuite()
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            suite.addTest(unittest.FunctionTestCase(value, description=name))
    return suite
