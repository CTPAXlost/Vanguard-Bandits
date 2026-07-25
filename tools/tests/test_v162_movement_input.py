from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "project" / "scripts" / "campaign_battle_v08.gd"
WORKFLOW = ROOT / ".github" / "workflows" / "build-windows.yml"


class MovementInputHotfixTests(unittest.TestCase):
    def test_child_input_handler_forwards_unconsumed_events_to_parent(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        start = text.index("func _unhandled_input(event: InputEvent) -> void:")
        end = text.index("\n\nfunc _open_target_picker", start)
        handler = text[start:end]
        self.assertGreaterEqual(handler.count("super._unhandled_input(event)"), 2)
        self.assertIn("Обычный режим: движение по клеткам", handler)
        self.assertIn("Щелчок мышью должен пройти", handler)

    def test_github_runs_real_mouse_click_movement_smoke(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("MovementInputSmoke.tscn", workflow)
        self.assertIn("MOVEMENT_INPUT_SMOKE_OK", workflow)
        self.assertTrue((ROOT / "project" / "scenes" / "MovementInputSmoke.tscn").is_file())
        self.assertTrue((ROOT / "project" / "scripts" / "movement_input_smoke.gd").is_file())


if __name__ == "__main__":
    unittest.main()
