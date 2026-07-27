from __future__ import annotations

import unittest

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


def test_mission_two_keeps_legacy_house_shape_for_runtime_regression() -> None:
    mission = json.loads((PROJECT / "data/maps/mission_02.json").read_text(encoding="utf-8"))
    houses = mission["houses"]
    assert houses, "Mission II must contain houses so the runtime path is exercised"
    for house in houses:
        assert len(house["size"]) == 2
        assert "height" in house


def test_house_builder_accepts_current_and_legacy_size_formats() -> None:
    script = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
    assert "if raw_size.size() >= 3:" in script
    assert "elif raw_size.size() >= 2:" in script
    assert 'float(data.get("height", 1.1))' in script
    assert "float(raw_size[1])" in script
    assert "float(raw_size[2])" in script


def test_all_house_records_have_a_supported_shape() -> None:
    for map_path in sorted((PROJECT / "data/maps").glob("mission_*.json")):
        mission = json.loads(map_path.read_text(encoding="utf-8"))
        for index, house in enumerate(mission.get("houses", [])):
            size = house.get("size", [])
            assert isinstance(size, list), f"{map_path.name} house {index}: size must be an array"
            assert len(size) in (1, 2, 3), f"{map_path.name} house {index}: unsupported size {size}"
            if len(size) < 3:
                assert "height" in house or len(size) == 1, (
                    f"{map_path.name} house {index}: legacy 2D size requires height"
                )


def test_release_version_is_196() -> None:
    project = (PROJECT / "project.godot").read_text(encoding="utf-8")
    assert 'config/version="1.9.13"' in project


def load_tests(loader: unittest.TestLoader, tests: unittest.TestSuite, pattern: str | None) -> unittest.TestSuite:
    suite = unittest.TestSuite()
    for name, value in sorted(globals().items()):
        if name.startswith("test_") and callable(value):
            suite.addTest(unittest.FunctionTestCase(value, description=name))
    return suite
