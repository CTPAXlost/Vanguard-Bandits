import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"
SLUGS = (
    "alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
    "sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
    "serata", "glaive",
)


class Version171OriginalSkinAnimationTests(unittest.TestCase):
    def test_every_atac_has_articulated_original_skin_parts(self) -> None:
        for slug in SLUGS:
            folder = PROJECT / "assets/atac_rigged" / slug
            meta_path = folder / "rig.json"
            self.assertTrue(meta_path.is_file(), meta_path)
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            self.assertEqual(meta["version"], "1.7.1")
            self.assertGreaterEqual(len(meta["parts"]), 10)
            self.assertTrue((PROJECT / meta["source"].replace("res://", "")).is_file())
            for part in meta["parts"]:
                path = PROJECT / part["texture"].replace("res://", "")
                self.assertTrue(path.is_file(), path)
                with Image.open(path) as image:
                    self.assertEqual(image.mode, "RGBA")
                    self.assertIsNotNone(image.getchannel("A").getbbox())

    def test_rig_uses_original_skin_not_box_body(self) -> None:
        script = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn("_build_original_skin()", script)
        self.assertIn("Sprite3D.new()", script)
        self.assertIn("BoneAttachment3D.new()", script)
        self.assertNotIn('func _build_armour()', script)
        self.assertNotIn('BoxMesh.new()\n\tmesh.size = size', script)

    def test_three_requested_attack_animations_are_keyed(self) -> None:
        rig = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        for mode in ("slash", "lunge", "long_lunge"):
            self.assertIn(f'"{mode}"', rig)
            self.assertIn(f'"{mode}"', battle)
        self.assertIn("_attack_curve", rig)
        self.assertIn("_spawn_long_lunge_effect", battle)
        self.assertIn("_apply_visual_pose", battle)

    def test_runtime_workflow_requires_original_skin_and_animation_markers(self) -> None:
        for workflow_name in ("build-windows.yml", "release-windows.yml"):
            text = (ROOT / ".github/workflows" / workflow_name).read_text(encoding="utf-8")
            self.assertIn("ORIGINAL_SKIN_RIG_SMOKE_OK", text)
            self.assertIn("BASIC_ATTACK_ANIMATION_SMOKE_OK", text)


if __name__ == "__main__":
    unittest.main()
