from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL_GALLERY = ROOT / "project/scripts/model_gallery.gd"
COMPILE_SMOKE = ROOT / "project/scripts/all_scripts_compile_smoke.gd"
WORKFLOWS = tuple((ROOT / ".github/workflows").glob("*.yml"))


class ModelGalleryCompileFixTests(unittest.TestCase):
    def test_release_version_is_1912(self) -> None:
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        presets = (ROOT / "project/export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.13"', project)
        self.assertEqual(2, presets.count('application/file_version="1.9.13.0"'))
        self.assertEqual(2, presets.count('application/product_version="1.9.13.0"'))

    def test_mouse_events_are_explicitly_cast_before_typed_properties(self) -> None:
        source = MODEL_GALLERY.read_text(encoding="utf-8")
        self.assertIn(
            "var mouse_button: InputEventMouseButton = event as InputEventMouseButton",
            source,
        )
        self.assertIn(
            "var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion",
            source,
        )
        self.assertIn(
            "var key_event: InputEventKey = event as InputEventKey",
            source,
        )
        self.assertIn(
            "var delta_mouse: Vector2 = mouse_motion.position - last_mouse",
            source,
        )
        self.assertNotRegex(source, r"var\s+delta_mouse\s*:=\s*event\.position")

    def test_compile_smoke_rejects_non_instantiable_scripts(self) -> None:
        source = COMPILE_SMOKE.read_text(encoding="utf-8")
        self.assertIn('ResourceLoader.load(', source)
        self.assertIn('"Script"', source)
        self.assertIn('ResourceLoader.CACHE_MODE_REPLACE', source)
        self.assertIn('loaded is Script', source)
        self.assertIn('script.can_instantiate()', source)
        self.assertIn('func _collect_scripts(directory_path: String) -> bool:', source)
        self.assertIn('if not _collect_scripts("res://"):', source)
        fail_pos = source.index('ALL_GDSCRIPT_COMPILE_FAILED')
        ok_pos = source.index('ALL_GDSCRIPT_COMPILE_OK')
        self.assertLess(fail_pos, ok_pos)

    def test_compile_workflow_still_blocks_on_engine_errors(self) -> None:
        self.assertTrue(WORKFLOWS)
        for workflow in WORKFLOWS:
            text = workflow.read_text(encoding="utf-8")
            self.assertIn("Compile every GDScript through Godot", text)
            self.assertIn("ALL_GDSCRIPT_COMPILE_FAILED", text)
            self.assertIn("ALL_GDSCRIPT_COMPILE_OK", text)
            self.assertIn("Parse Error", text)
            self.assertNotIn("continue-on-error", text)

    def test_no_generic_event_property_is_used_to_infer_delta_in_any_script(self) -> None:
        offenders = []
        pattern = re.compile(r"var\s+\w+\s*:=\s*event\.\w+")
        for path in (ROOT / "project/scripts").glob("*.gd"):
            source = path.read_text(encoding="utf-8")
            if pattern.search(source):
                offenders.append(path.name)
        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
