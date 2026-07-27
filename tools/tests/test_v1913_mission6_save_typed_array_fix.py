from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
CAMPAIGN_STATE = ROOT / "project/scripts/campaign_state.gd"
MISSION6_SMOKE = ROOT / "project/scripts/mission6_smoke.gd"
WORKFLOWS = tuple((ROOT / ".github/workflows").glob("*.yml"))


class Mission6SaveTypedArrayFixTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = CAMPAIGN_STATE.read_text(encoding="utf-8")

    def test_release_version_is_1913(self) -> None:
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "project/export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.13"', project)
        self.assertEqual(2, presets.count('application/file_version="1.9.13.0"'))
        self.assertEqual(2, presets.count('application/product_version="1.9.13.0"'))

    def test_mission6_unlocks_use_typed_constants_and_single_helper(self) -> None:
        for declaration in (
            'const SOUTH_ALLIANCE_CHARACTERS: Array[String] = ["logan", "claire", "shion"]',
            'const SOUTH_ALLIANCE_ATACS: Array[String] = ["crimson", "rahabar"]',
            'const NORTH_ALLIANCE_CHARACTERS: Array[String] = ["alden", "devlin", "barlow"]',
            'const NORTH_ALLIANCE_ATACS: Array[String] = ["altagrave", "snow_soldier", "ratatosk"]',
        ):
            self.assertIn(declaration, self.source)
        self.assertIn('func _unlock_kingdom_alliance(alliance: String) -> void:', self.source)
        self.assertEqual(2, self.source.count('_unlock_kingdom_alliance(kingdom_alliance)'))

    def test_no_typed_array_is_initialized_from_ternary_array_literals(self) -> None:
        offenders = []
        pattern = re.compile(
            r"var\s+\w+\s*:\s*Array\[[^\]]+\]\s*=\s*\[[^\n]*\]\s+if\s+[^\n]+\s+else\s+\["
        )
        for path in (ROOT / "project/scripts").glob("*.gd"):
            for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if pattern.search(line):
                    offenders.append(f"{path.name}:{line_number}")
        self.assertEqual([], offenders)

    def test_mission6_runtime_smoke_persists_both_alliances(self) -> None:
        smoke = MISSION6_SMOKE.read_text(encoding="utf-8")
        self.assertIn('await _check_branch("south")', smoke)
        self.assertIn('await _check_branch("north")', smoke)
        self.assertIn('CampaignState.complete_mission(6, branch)', smoke)
        self.assertIn('CampaignState.load_game()', smoke)
        self.assertIn('MISSION6_SAVE_%s_OK', smoke)

    def test_ci_keeps_mission6_smoke_blocking(self) -> None:
        self.assertTrue(WORKFLOWS)
        for workflow in WORKFLOWS:
            text = workflow.read_text(encoding="utf-8")
            self.assertIn('Runtime smoke test for war of two kingdoms', text)
            self.assertIn('MISSION6_SAVE_SOUTH_OK', text)
            self.assertIn('MISSION6_SAVE_NORTH_OK', text)
            self.assertIn('MISSION6_SMOKE_OK', text)
            self.assertNotIn('continue-on-error', text)


if __name__ == "__main__":
    unittest.main()
