from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class V184ZakovTriggerFixTests(unittest.TestCase):
    def test_wave_starts_immediately_without_deferred_string_call(self):
        source = (ROOT / "project/scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        self.assertIn("_start_zakov_reinforcement_spawn()", source)
        self.assertIn("_spawn_zakov_reinforcements_async()", source)
        self.assertNotIn('call_deferred("_spawn_zakov_reinforcements_async")', source)

    def test_smoke_validates_real_round_trigger(self):
        source = (ROOT / "project/scripts/mission5_smoke.gd").read_text(encoding="utf-8")
        self.assertIn('battle.call("_should_spawn_zakov_reinforcements")', source)
        self.assertIn("MISSION5_ZAKOV_TRIGGER_SMOKE_OK", source)
        self.assertIn('battle.get("zakov_reinforcements_arrived")', source)

    def test_lunge_effects_are_parented_before_look_at(self):
        source = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        first = source.index("func _spawn_lunge_effect")
        second = source.index("func _spawn_long_lunge_effect")
        block1 = source[first:second]
        block2 = source[second:source.index("func ", second + 10)]
        self.assertLess(block1.index("add_child(effect)"), block1.index("effect.look_at"))
        self.assertLess(block2.index("add_child(effect)"), block2.index("effect.look_at"))

    def test_project_version(self):
        project = (ROOT / "project/project.godot").read_text(encoding="utf-8")
        self.assertIn('config/version="1.9.7"', project)


if __name__ == "__main__":
    unittest.main()
