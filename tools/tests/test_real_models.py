from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "project" / "assets" / "imported" / "models"
VIEWS = ROOT / "project" / "assets" / "atac_views"


class RealModelPackageTests(unittest.TestCase):
    def test_extracted_reference_models_are_preserved(self) -> None:
        for slug in ("alba", "serata", "glaive"):
            folder = MODELS / slug
            self.assertTrue((folder / f"{slug}.obj").is_file())
            self.assertTrue((folder / f"{slug}.mtl").is_file())
            metadata_path = folder / "model.json"
            self.assertTrue(metadata_path.is_file())
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            self.assertGreater(metadata["exported_faces"], 700)
            self.assertGreater(metadata["bone_count"], 20)
            self.assertTrue(any((folder / "textures").glob("*.png")))

    def test_multiview_atac_assets_are_present(self) -> None:
        for slug in ("alba", "barbatos", "barazaph"):
            for view in ("front", "side", "back", "three_quarter"):
                path = VIEWS / slug / f"{view}.png"
                self.assertTrue(path.is_file(), path)
                self.assertGreater(path.stat().st_size, 20_000)
        self.assertTrue((VIEWS / "sword_level_1.png").is_file())

    def test_multiview_factory_keeps_animation_pivots(self) -> None:
        factory = (ROOT / "project/scripts/atac_factory.gd").read_text(encoding="utf-8")
        visual = (ROOT / "project/scripts/multiview_atac.gd").read_text(encoding="utf-8")
        self.assertIn("MultiViewAtac", factory)
        for marker in (
            'pivot.name = pivot_name',
            'right_arm_pivot.name = "RightArmPivot"',
            'weapon_pivot.name = "WeaponPivot"',
            'sprite.billboard',
            'three_quarter',
            'barazaph',
        ):
            self.assertIn(marker, visual)

    def test_user_reference_package_is_present(self) -> None:
        refs = ROOT / "docs" / "references" / "remaster_models"
        expected = {
            "alba_front.jpg",
            "alba_turnaround.jpg",
            "imperial_atac_turnaround.jpg",
            "level_1_sword.jpg",
            "bastion_portrait.jpg",
            "imperial_soldier_portrait.jpg",
        }
        self.assertTrue(expected.issubset({path.name for path in refs.glob("*.jpg")}))


if __name__ == "__main__":
    unittest.main()
