from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUB = ROOT / "project" / "scripts" / "campaign_hub.gd"


class CampaignHubParseFixTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = HUB.read_text(encoding="utf-8")

    def test_button_callbacks_are_declared(self) -> None:
        callbacks = re.findall(r'_add_button\([^\n]*,\s*([A-Za-z_][A-Za-z0-9_]*)\)', self.source)
        declared = set(re.findall(r'^func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(', self.source, flags=re.MULTILINE))
        missing = sorted({name for name in callbacks if name not in declared})
        self.assertEqual([], missing, f"CampaignHub button callbacks without functions: {missing}")

    def test_save_progress_persists_campaign(self) -> None:
        self.assertRegex(
            self.source,
            r'func _save_progress\(\) -> void:\s*\n\s*CampaignState\.save_game\(\)',
        )

    def test_character_panel_can_be_opened(self) -> None:
        self.assertRegex(
            self.source,
            r'func _open_characters\(\) -> void:[\s\S]*?character_panel\.visible\s*=\s*true',
        )


if __name__ == "__main__":
    unittest.main()

class FullGDScriptCompileGateTests(unittest.TestCase):
    def test_compile_smoke_scene_and_script_exist(self) -> None:
        self.assertTrue((ROOT / "project/scenes/AllScriptsCompileSmoke.tscn").is_file())
        script = (ROOT / "project/scripts/all_scripts_compile_smoke.gd").read_text(encoding="utf-8")
        self.assertIn("ALL_GDSCRIPT_COMPILE_OK", script)
        self.assertIn("load(script_path)", script)

    def test_both_workflows_run_compile_gate_before_missions(self) -> None:
        for workflow in (ROOT / ".github/workflows").glob("*.yml"):
            text = workflow.read_text(encoding="utf-8")
            compile_pos = text.index("Compile every GDScript through Godot")
            mission_pos = text.index("Blocking boot smoke for missions 1-6")
            self.assertLess(compile_pos, mission_pos, workflow.name)
            self.assertIn("ALL_GDSCRIPT_COMPILE_OK", text)
            self.assertNotIn("continue-on-error", text)
