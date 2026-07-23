from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class V081RuntimeFixTests(unittest.TestCase):
    def test_actions_node_and_typed_variable_match(self) -> None:
        scene = (ROOT / "project/scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        script = (ROOT / "project/scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        match = re.search(
            r'^\[node name="Actions" type="([^"]+)" parent="HUD/CommandPanel/Margin/VBox"\]$',
            scene,
            re.MULTILINE,
        )
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), "GridContainer")
        self.assertIn(
            "var actions: GridContainer = $HUD/CommandPanel/Margin/VBox/Actions",
            script,
        )
        self.assertNotIn(
            "var actions: HBoxContainer = $HUD/CommandPanel/Margin/VBox/Actions",
            script,
        )

    def test_upgrade_button_is_created_before_base_ready(self) -> None:
        script = (ROOT / "project/scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        build_pos = script.index("_build_v08_interface()")
        super_pos = script.index("super._ready()")
        create_pos = script.index("upgrade_button = Button.new()")
        self.assertLess(build_pos, super_pos)
        self.assertGreater(create_pos, build_pos)


if __name__ == "__main__":
    unittest.main()
