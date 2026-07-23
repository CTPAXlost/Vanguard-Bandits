import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class V06CombatTests(unittest.TestCase):
    def test_balance_has_kamorge_and_energy(self):
        data = json.loads((ROOT / "project/data/balance/level_01_units.json").read_text(encoding="utf-8"))
        self.assertEqual(data["bastion_alba"]["atac_name"], "Alba")
        self.assertEqual(data["imperial_soldier"]["atac_name"], "Barbatos")
        self.assertEqual(data["kamorge_barazaph"]["level"], 16)
        self.assertEqual(data["kamorge_barazaph"]["atac_name"], "Barazaph")
        self.assertEqual(data["kamorge_barazaph"]["max_energy"], 60)
        self.assertIn("Шаровая молния", data["kamorge_barazaph"]["attacks"])

    def test_mission_uses_barbatos_and_kamorge_trigger(self):
        data = json.loads((ROOT / "project/data/maps/mission_01.json").read_text(encoding="utf-8"))
        self.assertTrue(all(e["atac"] == "barbatos" for e in data["enemies"]))
        self.assertIn("kamorge_spawn", data)

    def test_scene_has_reaction_ability_dialogue_and_energy_ui(self):
        scene = (ROOT / "project/scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        for name in [
            "FatigueBar", "EnergyBar", "AttackMenu", "BallLightning", "AbilityMenu",
            "ReactionMenu", "DialoguePanel", "Reflect", "TakeHit",
        ]:
            self.assertIn(f'name="{name}"', scene)

    def test_combat_script_has_v06_mechanics(self):
        script = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        required = [
            "func _run_ally_phase",
            "func _spawn_kamorge_event",
            "func _request_player_reaction",
            "func _animate_ball_lightning",
            "ENERGY_BALL_LIGHTNING := 30",
            '"Ах вот ты где?!?',
            '"Отец, я справлюсь',
            '"Ну уж нет, я иду.',
            'str(unit.get_meta("team")) == "enemy"',
            "func _animate_path",
            "func _toggle_ability_menu",
        ]
        for token in required:
            self.assertIn(token, script)

    def test_enemy_step_count_has_explicit_integer_type(self):
        script = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn(
            'var steps: int = mini(int(_stats(enemy).get("move_range", 5)), path.size())',
            script,
        )

    def test_multiview_runtime_is_used(self):
        factory = (ROOT / "project/scripts/atac_factory.gd").read_text(encoding="utf-8")
        runtime = (ROOT / "project/scripts/multiview_atac.gd").read_text(encoding="utf-8")
        self.assertIn("MultiViewAtac.new()", factory)
        self.assertIn("Sprite3D", runtime)
        self.assertIn("SHARED_TEXTURES", runtime)
        self.assertIn("CACHE_MODE_REUSE", runtime)
        self.assertNotIn("CACHE_MODE_IGNORE", runtime)
        self.assertIn("camera.global_position", runtime)


if __name__ == "__main__":
    unittest.main()
