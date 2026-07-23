import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"

class V16TacticsAnimationTests(unittest.TestCase):
    def test_arena_removed_and_tactical_animation_enabled(self):
        state=(PROJECT/"scripts/campaign_state.gd").read_text(encoding="utf-8")
        battle=(PROJECT/"scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        self.assertIn("arena_battles_enabled: bool = false", state)
        self.assertIn("battle_arena = null", battle)

    def test_target_picker_keyboard_and_hp(self):
        battle=(PROJECT/"scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for token in ["func _open_target_picker", "func _confirm_target_picker", "HP %d/%d", "ui_accept", "ui_cancel"]:
            self.assertIn(token,battle)

    def test_facing_uses_arrows_and_map_relative_names(self):
        battle=(PROJECT/"scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for token in ["↑ Верх карты", "↓ Низ карты", "← Лево карты", "→ Право карты", "ui_left", "ui_right"]:
            self.assertIn(token,battle)

    def test_move_can_be_undone_before_action(self):
        battle=(PROJECT/"scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for token in ["func _undo_last_move", "move_undo_snapshot", "Перемещение отменено", "unit.position = move_undo_snapshot"]:
            self.assertIn(token,battle)

    def test_individual_attack_effect_layer(self):
        battle=(PROJECT/"scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        for token in ["_spawn_focus_ring", "_spawn_impact_sparks", "_attack_color", "ice_rain", "ball_lightning", "bright_bomb", "desert_storm", "ultrasound"]:
            self.assertIn(token,battle)

if __name__ == "__main__": unittest.main()
