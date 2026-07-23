import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "project"


class CampaignV12Tests(unittest.TestCase):
    def test_castle_mission_has_requested_forces(self):
        data = json.loads((PROJECT / "data/maps/mission_04.json").read_text(encoding="utf-8"))
        self.assertEqual(data["status"], "campaign_v12_castle_rescue")
        self.assertEqual(len(data["enemy_starts"]["captains"]), 4)
        self.assertEqual(len(data["reinforcement_starts"]["kingdom"]), 5)
        battle = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        for marker in ("General Zakov", "Duyere", "Galvas", "_spawn_castle_reinforcements", "_check_duyere_retreat", "0.40"):
            self.assertIn(marker, battle)

    def test_eigol_serata_and_zakov_mechanics(self):
        catalog = (PROJECT / "scripts/combat_catalog.gd").read_text(encoding="utf-8")
        battle = (PROJECT / "scripts/campaign_battle_v12.gd").read_text(encoding="utf-8")
        for marker in ("desert_storm", "sticky_sandstorm", "healing_ban", '"energy": 35', '"energy": 50'):
            self.assertIn(marker, catalog)
        for marker in ("serata_restoration_aura", "+ 15", "zakov_trap", "round_number % 5", "strongest_block_turns"):
            self.assertIn(marker, battle)

    def test_shared_shop_and_opal(self):
        state = (PROJECT / "scripts/campaign_state.gd").read_text(encoding="utf-8")
        shop = (PROJECT / "scripts/shop.gd").read_text(encoding="utf-8")
        self.assertTrue((PROJECT / "scenes/Shop.tscn").is_file())
        for marker in ("SHOP_ITEMS", "get_sell_price", "0.40", "character_has_opal", "opal_skill_stone"):
            self.assertIn(marker, state)
        for marker in ("Общий фонд команды", "Купить в общий склад", "Продать за 40%", "Экипировать выбранный предмет"):
            self.assertIn(marker, shop)

    def test_experimental_real_3d_has_fallback(self):
        factory = (PROJECT / "scripts/atac_factory.gd").read_text(encoding="utf-8")
        rig = (PROJECT / "scripts/real_model_atac.gd").read_text(encoding="utf-8")
        self.assertIn("experimental_3d_enabled", factory)
        self.assertIn("MultiViewAtac", factory)
        self.assertIn("real_3d_model", rig)
        for slug in ("alba", "serata", "glaive"):
            self.assertTrue((PROJECT / f"assets/imported/models/{slug}/{slug}.obj").is_file())

    def test_new_visual_assets_have_transparency(self):
        for slug in ("serata", "glaive", "eigol", "einlager"):
            for view in ("front", "back", "side", "three_quarter"):
                path = PROJECT / "assets/atac_views" / slug / f"{view}.png"
                image = Image.open(path).convert("RGBA")
                low, high = image.getchannel("A").getextrema()
                self.assertEqual(low, 0, path)
                self.assertEqual(high, 255, path)


if __name__ == "__main__":
    unittest.main()
