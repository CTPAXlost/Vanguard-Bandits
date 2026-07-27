import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class Version17SkeletalVfxCleanupTests(unittest.TestCase):
    def test_project_version_header(self) -> None:
        project_text = (PROJECT / "project.godot").read_text(encoding="utf-8")
        self.assertIn("1.9.14", project_text)
        self.assertIn("original ATAC skins on Skeleton3D", project_text)

    def test_every_campaign_atac_has_skeletal_renderer_support(self) -> None:
        script = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn("class_name SkeletalAtac", script)
        self.assertIn("Skeleton3D.new()", script)
        self.assertIn("BoneAttachment3D.new()", script)
        self.assertIn('set_meta("real_skeleton", true)', script)
        for slug in (
            "alba", "barbatos", "barazaph", "vedocorban", "cador", "solarus",
            "sarbelas", "einlager", "eigol", "amphisia", "haurol", "toreadore",
            "serata", "glaive",
        ):
            self.assertIn(f'"{slug}"', script)

    def test_tactical_factory_uses_skeletons_not_camera_facing_sheets(self) -> None:
        factory = (PROJECT / "scripts/atac_factory.gd").read_text(encoding="utf-8")
        self.assertIn('if render_context == "tactical"', factory)
        self.assertIn("SkeletalAtac.supports(normalized)", factory)
        self.assertIn("skeletal_root.configure(normalized)", factory)
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn('AtacFactory.create_atac(model_slug, "tactical")', battle)
        campaign = (PROJECT / "scripts/campaign_battle.gd").read_text(encoding="utf-8")
        self.assertIn('AtacFactory.create_atac("cador", "tactical")', campaign)

    def test_skeletal_models_share_original_skin_textures(self) -> None:
        script = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn("static var TEXTURE_CACHE", script)
        self.assertIn('set_meta("original_skin_rig", true)', script)
        self.assertIn("custom_aabb = SAFE_AABB", script)
        self.assertIn("CACHE_MODE_REUSE", script)

    def test_defeated_atac_is_hidden_unblocked_removed_and_freed(self) -> None:
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        for required in (
            "_mark_defeated_invisible(target)",
            'unit.visible = false',
            'unit.set_meta("cell", Vector2i(-9999, -9999))',
            "units.erase(unit)",
            "unit.queue_free()",
        ):
            self.assertIn(required, battle)
        self.assertTrue((PROJECT / "scenes/DeathCleanupSmoke.tscn").is_file())
        self.assertTrue((PROJECT / "scripts/death_cleanup_smoke.gd").is_file())

    def test_all_storyboard_effect_sequences_exist_with_alpha(self) -> None:
        vfx_root = PROJECT / "assets/vfx/storyboard"
        modes = (
            "bright_bomb", "sticky_sandstorm", "quicksand",
            "desert_storm", "ice_rain", "ball_lightning",
        )
        for mode in modes:
            for index in range(1, 5):
                image_path = vfx_root / mode / f"{index}.png"
                self.assertTrue(image_path.is_file(), image_path)
                with Image.open(image_path) as image:
                    self.assertEqual(image.mode, "RGBA")
                    alpha = image.getchannel("A")
                    low, high = alpha.getextrema()
                    self.assertLess(low, 255)
                    self.assertGreater(high, 0)

    def test_storyboard_effects_are_wired_to_combat(self) -> None:
        v08 = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        v12 = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        for mode in ("bright_bomb", "quicksand", "ice_rain", "ball_lightning"):
            self.assertIn(f'CinematicVfx.play(self, "{mode}"', v08)
        for mode in ("desert_storm", "sticky_sandstorm"):
            self.assertIn(f'CinematicVfx.play(self, "{mode}"', v12)

    def test_github_runs_skeleton_and_cleanup_runtime_smokes(self) -> None:
        for workflow_name in ("build-windows.yml", "release-windows.yml"):
            workflow = (ROOT / ".github/workflows" / workflow_name).read_text(encoding="utf-8")
            self.assertIn("VisibilitySmoke.tscn", workflow)
            self.assertIn("SKELETAL_ATAC_SMOKE_OK", workflow)
            self.assertIn("DeathCleanupSmoke.tscn", workflow)
            self.assertIn("DEATH_CLEANUP_SMOKE_OK", workflow)


if __name__ == "__main__":
    unittest.main()
