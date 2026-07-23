from pathlib import Path
import json
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class V09BranchingTests(unittest.TestCase):
    def test_eigol_assets_and_data(self):
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        self.assertIn('"eigol"', state)
        self.assertIn('"desert_whirl"', catalog)
        self.assertIn('"quicksand"', catalog)
        for view in ("front", "back", "side", "three_quarter"):
            path = PROJECT / "assets/atac_views/eigol" / f"{view}.png"
            self.assertTrue(path.is_file())
            image = Image.open(path).convert("RGBA")
            self.assertEqual(image.getchannel("A").getextrema()[0], 0)

    def test_branch_story_and_prison_scene(self):
        battle = (PROJECT / "scripts/campaign_battle_v08.gd").read_text(encoding="utf-8")
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        story = (PROJECT / "scripts/story_chapter.gd").read_text(encoding="utf-8")
        for marker in (
            "Я не смог защитить тебя",
            "Нее-е-ет! Отец",
            "_animate_faulkner_final_strike",
            "_play_faulkner_kamorge_duel",
            "_animate_kamorge_river_jump",
            "_play_forced_capture_outro",
            "Зыбучие пески",
            "Вихрь в пустыне",
        ):
            self.assertIn(marker, battle)
        self.assertIn("kamorge_alive", state)
        self.assertIn("mission_4_complete", state)
        self.assertIn("Имперская тюрьма", story)
        self.assertIn("Лесной лагерь партизан", story)
        self.assertTrue((PROJECT / "assets/story/imperial_prison.png").is_file())
        self.assertTrue((PROJECT / "scenes/StoryChapter.tscn").is_file())

    def test_mission_four_has_four_imperials(self):
        data = json.loads((PROJECT / "data/maps/mission_04.json").read_text(encoding="utf-8"))
        self.assertEqual(data["mission_number"], 4)
        self.assertEqual(len(data["enemies"]), 4)
        self.assertTrue(all(e["atac"] == "barbatos" for e in data["enemies"]))

    def test_visuals_are_compact_and_unshaded(self):
        visual = (PROJECT / "scripts/multiview_atac.gd").read_text(encoding="utf-8")
        self.assertIn("sprite.shaded = false", visual)
        self.assertIn("outline_sprite.visible = false", visual)
        self.assertIn("0.00218", visual)
        battle = (PROJECT / "scripts/battle_prototype.gd").read_text(encoding="utf-8")
        self.assertIn("0.58", battle)


if __name__ == "__main__":
    unittest.main()
