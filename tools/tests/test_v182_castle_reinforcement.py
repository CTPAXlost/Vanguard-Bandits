import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V182CastleReinforcementTests(unittest.TestCase):
    def test_map_has_requested_neutral_and_reinforcement_positions(self):
        data = json.loads((PROJECT / "data/maps/mission_05.json").read_text(encoding="utf-8"))
        self.assertEqual(data["neutral_starts"], {
            "sadira": [17, 17], "franco": [15, 17], "halak": [19, 17]
        })
        wave = data["reinforcement_starts"]
        self.assertEqual(len(wave["captains"]), 2)
        self.assertEqual(len(wave["barbatos"]), 3)
        self.assertEqual(wave["zakov"], [1, 9])

    def test_sharking_catalog_stats_and_mechanics(self):
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/campaign_battle_v18.gd").read_text(encoding="utf-8")
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        for marker in (
            '"sharking_slash"', '"energy": 20',
            '"sharking_strong_slash"', '"energy": 35',
            '"force_field_throw"', '"energy": 45', '"range": 4',
            '"zakov_sharking"',
        ):
            self.assertIn(marker, catalog)
        for marker in (
            "SHARKING_REINFORCEMENT_ROUND", "zakov_reinforcements_arrived",
            'sharking_stats["armor"] = 250', 'sharking_stats["max_armor"] = 250',
            'sharking_stats["move_range"] = 10', 'rng.randf() <= 0.70',
            'unit.get_meta("armor_regen", 50)', "_animate_force_field_throw",
            "DefenseCastleGateWest", "DefenseCastleGateEast",
        ):
            self.assertIn(marker, battle)
        self.assertIn('"sharking": {', state)

    def test_sharking_and_new_character_rigs_are_articulated(self):
        required_bones = {
            "head", "chest", "pelvis", "upper_arm_l", "lower_arm_l",
            "upper_arm_r", "lower_arm_r", "upper_leg_l", "lower_leg_l",
            "upper_leg_r", "lower_leg_r",
        }
        for slug in ("sylpheed", "korbelan", "sharking"):
            rig_dir = PROJECT / f"assets/atac_rigged/{slug}"
            rig = json.loads((rig_dir / "rig.json").read_text(encoding="utf-8"))
            bones = {part["bone"] for part in rig["parts"]}
            self.assertTrue(required_bones.issubset(bones), (slug, required_bones - bones))
            self.assertNotIn("torso", bones)
            self.assertGreaterEqual(len(rig["parts"]), 11)
            for part in rig["parts"]:
                texture = PROJECT / part["texture"].replace("res://", "")
                self.assertTrue(texture.exists(), texture)
                with Image.open(texture) as image:
                    self.assertEqual(image.mode, "RGBA")
                    self.assertGreater(image.getchannel("A").getbbox()[2], 20)

    def test_portraits_are_high_resolution_user_assets(self):
        for name in ("sadira.png", "franco.png", "halak.png", "zakov.png", "captain_soldiers.png"):
            path = PROJECT / "assets/ui/portraits" / name
            self.assertTrue(path.exists(), path)
            with Image.open(path) as image:
                self.assertGreaterEqual(image.width, 768)
                self.assertGreaterEqual(image.height, 768)

    def test_weapon_overlay_is_attached_to_hand_not_floating(self):
        source = (PROJECT / "scripts/skeletal_atac.gd").read_text(encoding="utf-8")
        self.assertIn('_attachment("hand_r").add_child(weapon)', source)
        self.assertNotIn('Vector3(0.30, -0.05, 0.012)', source)
        self.assertIn('Vector3(0.015, 0.265, 0.012)', source)
        self.assertIn('"sylpheed", "sharking"', source)

    def test_zeira_magic_uses_selected_ally(self):
        source = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        for marker in (
            'pending_attack_mode = "__restore_energy__"',
            "_energy_magic_targets", "_apply_toreadore_energy_magic",
            "Выберите союзника", 'target.set_meta("stats", target_stats)',
        ):
            self.assertIn(marker, source)


if __name__ == "__main__":
    unittest.main()
