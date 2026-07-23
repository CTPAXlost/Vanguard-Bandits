from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class FirstMissionTests(unittest.TestCase):
    def test_turn_based_map_data_is_complete(self) -> None:
        data = json.loads(
            (ROOT / "project" / "data" / "maps" / "mission_01.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(data["id"], "mission_01_border_village")
        self.assertEqual(len(data["enemies"]), 3)
        self.assertEqual(sum(1 for enemy in data["enemies"] if enemy["commander"]), 1)
        self.assertTrue(
            all(enemy["atac"] == "barbatos" for enemy in data["enemies"])
        )
        self.assertGreaterEqual(len(data["blocked_cells"]), 20)
        blocked = {tuple(cell) for cell in data["blocked_cells"]}
        starts = [tuple(data["player_start"])] + [tuple(enemy["cell"]) for enemy in data["enemies"]]
        self.assertEqual(len(starts), len(set(starts)))
        self.assertTrue(all(cell not in blocked for cell in starts))

    def test_turn_order_and_actions_are_implemented(self) -> None:
        script = (ROOT / "project" / "scripts" / "battle_prototype.gd").read_text(
            encoding="utf-8"
        )
        for marker in (
            "_begin_player_turn",
            "_run_enemy_phase",
            "_show_reachable_cells",
            "_animate_slash",
            "_animate_lunge",
            "_player_defend",
            "_calculate_damage",
            "BALANCE_PATH",
        ):
            self.assertIn(marker, script)

        balance = json.loads(
            (
                ROOT / "project" / "data" / "balance" / "level_01_units.json"
            ).read_text(encoding="utf-8")
        )
        self.assertEqual(balance["bastion_alba"]["hp"], 180)
        self.assertEqual(balance["bastion_alba"]["move_range"], 6)
        self.assertEqual(balance["imperial_soldier"]["hp"], 90)
        self.assertEqual(balance["imperial_soldier"]["move_range"], 5)
        self.assertEqual(balance["imperial_commander"]["hp"], 110)

    def test_portraits_and_command_ui_exist(self) -> None:
        scene = (ROOT / "project" / "scenes" / "BattlePrototype.tscn").read_text(
            encoding="utf-8"
        )
        for control in ("Portrait", "Attack", "AttackMenu", "Slash", "Lunge", "LongLunge", "Defend", "EndTurn"):
            self.assertIn(f'name="{control}"', scene)
        for portrait in ("bastion.png", "imperial_soldier.png"):
            self.assertTrue(
                (
                    ROOT
                    / "project"
                    / "assets"
                    / "ui"
                    / "portraits"
                    / portrait
                ).is_file()
            )

    def test_github_workflow_exports_windows(self) -> None:
        workflow = (
            ROOT / ".github" / "workflows" / "build-windows.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("--export-release", workflow)
        self.assertIn("Vanguard Bandits Remaster.exe", workflow)


if __name__ == "__main__":
    unittest.main()
