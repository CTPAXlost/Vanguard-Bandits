import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V15ArenaVisibilityTests(unittest.TestCase):
    def test_tactical_rig_cannot_turn_edge_on_or_be_culled_early(self) -> None:
        script = (PROJECT / "scripts/multiview_atac.gd").read_text(encoding="utf-8")
        for token in [
            'billboard_root.name = "CameraFacingRoot"',
            "billboard_root.top_level = true",
            "billboard_root.look_at(target, Vector3.UP, true)",
            "BILLBOARD_DISABLED",
            "ALPHA_CUT_OPAQUE_PREPASS",
            "ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE",
            "TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC",
            "custom_aabb = SAFE_VISIBILITY_AABB",
            "double_sided = true",
        ]:
            self.assertIn(token, script)
        self.assertIn("Vector3(0, 0, -0.018)", script)

    def test_tactical_animation_is_shared_by_player_allies_enemies_and_counterattacks(self) -> None:
        battle = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        block = battle.split("func _play_attack_animation", 1)[1].split("func _animate_desert_storm_v12", 1)[0]
        self.assertIn("_begin_tactical_attack_presentation", block)
        self.assertIn("_finish_tactical_attack_presentation", block)
        self.assertNotIn('get_meta("player"', block)

    def test_combatants_face_each_other_and_arena_has_cinematic_effects(self) -> None:
        arena = (PROJECT / "scripts/battle_arena_director.gd").read_text(encoding="utf-8")
        real = (PROJECT / "scripts/real_model_atac.gd").read_text(encoding="utf-8")
        self.assertIn("func _face_combatants", arena)
        self.assertIn('set_arena_view", "three_quarter", false', arena)
        self.assertIn('set_arena_view", "three_quarter", true', arena)
        self.assertRegex(real, re.compile(r"func set_arena_facing\(is_attacker: bool\).*?-90\.0 if is_attacker else 90\.0", re.S))
        for token in [
            "_spawn_slash_combo",
            "_spawn_impact_burst",
            "_spawn_projectile_trail",
            "_spawn_lightning_cage",
            "_animate_ice_rain",
            "_animate_ultrasound",
            "_animate_sand_magic",
            "_animate_quicksand",
            "_animate_healing_ban",
            "_camera_shake",
            "Hit-stop",
        ]:
            self.assertIn(token, arena)

    def test_runtime_smokes_cover_ai_arena_and_four_camera_angles(self) -> None:
        arena_smoke = (PROJECT / "scripts/arena_smoke.gd").read_text(encoding="utf-8")
        visibility_smoke = (PROJECT / "scripts/visibility_smoke.gd").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn('attacker.set_meta("player", false)', arena_smoke)
        self.assertIn("ARENA_V15_AI_OK", arena_smoke)
        self.assertIn("ARENA_V15_AI_OK", workflow)
        self.assertIn("VisibilitySmoke.tscn", workflow)
        self.assertIn("TACTICAL_VISIBILITY_SMOKE_OK", workflow)
        self.assertIn("camera_positions: Array[Vector3]", visibility_smoke)
        self.assertIn("TACTICAL_VISIBILITY_EDGE_ON_FAILED", visibility_smoke)
        self.assertIn("TACTICAL_VIEW_SWAP_FAILED", visibility_smoke)
        self.assertGreaterEqual(visibility_smoke.count("Vector3("), 6)

    def test_project_header_identifies_v15(self) -> None:
        project = (PROJECT / "project.godot").read_text(encoding="utf-8")
        self.assertIn('config/name="Vanguard Bandits Remaster"', project)
        self.assertIn('config/version="1.9.6"', project)


if __name__ == "__main__":
    unittest.main()
