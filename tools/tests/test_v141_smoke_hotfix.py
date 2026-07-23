import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class V141SmokeHotfixTests(unittest.TestCase):
    def test_arena_smoke_gets_enough_frames(self):
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        self.assertIn("ArenaSmoke.tscn --quit-after 2400", workflow)
        self.assertIn('grep -q "ARENA_SMOKE_OK"', workflow)

    def test_mission_smokes_are_safe_and_marked(self):
        workflow = (ROOT / ".github/workflows/build-windows.yml").read_text(encoding="utf-8")
        for mission, marker in [(3, "MISSION3_SMOKE_OK"), (4, "MISSION4_SMOKE_OK")]:
            script = (ROOT / f"project/scripts/mission{mission}_smoke.gd").read_text(encoding="utf-8")
            self.assertNotIn("change_scene_to_file", script)
            self.assertIn("await get_tree().process_frame", script)
            self.assertIn(marker, script)
            self.assertIn(f'grep -q "{marker}"', workflow)

    def test_arena_cleanup_is_deferred(self):
        script = (ROOT / "project/scripts/battle_arena_director.gd").read_text(encoding="utf-8")
        block = script.split("func _clear_combatants()", 1)[1].split("func _animate_attack", 1)[0]
        self.assertNotIn("remove_child", block)
        self.assertIn("queue_free()", block)


if __name__ == "__main__":
    unittest.main()
