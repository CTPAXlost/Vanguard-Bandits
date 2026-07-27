import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = [
    ROOT / ".github/workflows/build-windows.yml",
    ROOT / ".github/workflows/release-windows.yml",
]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class V199CINormalSceneBootTests(unittest.TestCase):
    def test_release_version_is_199(self) -> None:
        self.assertIn('config/version="1.9.12"', read(ROOT / "project/project.godot"))

    def test_obsolete_standalone_script_chain_smoke_is_removed(self) -> None:
        self.assertFalse((ROOT / "project/scripts/script_chain_smoke.gd").exists())
        for workflow in WORKFLOWS:
            text = read(workflow)
            self.assertNotIn("--script res://scripts/script_chain_smoke.gd", text)

    def test_battle_chain_is_booted_through_normal_scene_lifecycle(self) -> None:
        scene = read(ROOT / "project/scenes/MissionBootSmoke.tscn")
        script = read(ROOT / "project/scripts/mission_boot_smoke.gd")
        self.assertIn('instance=ExtResource("2")', scene)
        self.assertIn('path="res://scenes/BattlePrototype.tscn"', scene)
        self.assertIn('CampaignState.prepare_mission_for_test', script)
        self.assertIn('MISSION_BOOT_SMOKE_OK mission=%d branch=%s', script)
        self.assertIn('MISSION_BOOT_SMOKE_FAILED', script)

    def test_both_workflows_block_all_required_mission_boots(self) -> None:
        required = (
            '"1:"', '"2:"', '"3:stay_and_fight"', '"3:seek_southern_aid"',
            '"4:seek_southern_aid"', '"5:defend_castle"', '"6:south"', '"6:north"',
        )
        for workflow in WORKFLOWS:
            text = read(workflow)
            for spec in required:
                self.assertIn(spec, text)
            self.assertIn('res://scenes/MissionBootSmoke.tscn', text)
            self.assertIn('STATUS=${PIPESTATUS[0]}', text)
            self.assertIn('grep -Fq "MISSION_BOOT_SMOKE_OK mission=${mission} branch=${branch}"', text)
            self.assertIn('MISSION_BOOT_SMOKE_FAILED', text)
            self.assertNotIn('continue-on-error', text)

    def test_import_and_export_are_blocking_and_logged(self) -> None:
        for workflow in WORKFLOWS:
            text = read(workflow)
            self.assertIn('--import --quit-after 300 2>&1 | tee godot-import.log', text)
            self.assertIn('Failed to load script|Compilation failed', text)
            self.assertIn('--export-release', text)
            self.assertIn('2>&1 | tee windows-export.log', text)
            self.assertIn('test -s "build/windows/Vanguard Bandits Remaster.exe"', text)


if __name__ == "__main__":
    unittest.main()
