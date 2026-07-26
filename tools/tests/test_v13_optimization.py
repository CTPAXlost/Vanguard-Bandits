import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class V13OptimizationTests(unittest.TestCase):
    def test_frame_cap_vsync_and_guard_are_enabled(self):
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        self.assertIn("run/max_fps=60", project)
        self.assertIn("run/low_processor_mode=true", project)
        self.assertIn("window/vsync/vsync_mode=1", project)
        self.assertIn('PerformanceGuard="*res://scripts/performance_guard.gd"', project)
        state = (ROOT / "project/scripts/campaign_state.gd").read_text(encoding="utf-8")
        self.assertIn("SAVE_VERSION: int = 20", state)
        self.assertIn("experimental_3d_enabled: bool = false", state)
        self.assertIn("_migrate_performance_settings", state)

    def test_performance_guard_logs_gpu_ram_and_draw_calls(self):
        guard = (ROOT / "project/scripts/performance_guard.gd").read_text(encoding="utf-8")
        for token in [
            "get_video_adapter_name",
            "MEMORY_STATIC",
            "RENDERING_INFO_TEXTURE_MEM_USED",
            "RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME",
            "performance_v13.log",
            "KEY_F9",
            "KEY_F10",
        ]:
            self.assertIn(token, guard)

    def test_terrain_and_castle_are_batched(self):
        battle = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        castle = (ROOT / "project/scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        self.assertIn("MultiMeshInstance3D", battle)
        self.assertIn("_build_terrain_multimeshes", battle)
        self.assertIn('"CastleWalls", wall_transforms', castle)
        self.assertNotIn("eigol_visual.visible = false", castle)
        self.assertNotIn("func _create_tile(", battle)

    def test_multiview_textures_are_lazy_and_shared(self):
        runtime = (ROOT / "project/scripts/multiview_atac.gd").read_text(encoding="utf-8")
        self.assertIn("static var SHARED_TEXTURES", runtime)
        self.assertIn("VIEW_UPDATE_INTERVAL", runtime)
        self.assertIn("CACHE_MODE_REUSE", runtime)
        self.assertNotIn("CACHE_MODE_IGNORE", runtime)
        self.assertNotIn('"serata", "glaive", "barbatos"', runtime)

    def test_optimized_glb_assets_are_allowed_by_gitignore(self):
        gitignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
        self.assertIn("!project/assets/imported/models/optimized/", gitignore)
        self.assertIn("!project/assets/imported/models/optimized/**", gitignore)


    def test_real_models_use_single_material_glb_fallback(self):
        runtime = (ROOT / "project/scripts/real_model_atac.gd").read_text(encoding="utf-8")
        self.assertIn("optimized.glb", runtime)
        self.assertIn("PackedScene", runtime)
        self.assertIn("CACHE_MODE_REUSE", runtime)
        for slug in ["alba", "serata", "glaive"]:
            path = ROOT / f"project/assets/imported/models/optimized/{slug}_optimized.glb"
            self.assertTrue(path.exists(), path)
            self.assertLess(path.stat().st_size, 2_000_000)


if __name__ == "__main__":
    unittest.main()
