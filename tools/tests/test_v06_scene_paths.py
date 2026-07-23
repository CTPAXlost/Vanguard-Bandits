from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class V06ScenePathTests(unittest.TestCase):
    def test_onready_paths_exist_in_battle_scene(self) -> None:
        scene_text = (ROOT / "project/scenes/BattlePrototype.tscn").read_text(encoding="utf-8")
        script_text = (ROOT / "project/scripts/battle_prototype.gd").read_text(encoding="utf-8")
        paths = set()
        for match in re.finditer(
            r'^\[node name="([^"]+)" type="[^"]+"(?: parent="([^"]+)")?\]$',
            scene_text,
            re.MULTILINE,
        ):
            name, parent = match.groups()
            if parent is None:
                paths.add(name)
            elif parent == ".":
                paths.add(name)
            else:
                paths.add(f"{parent}/{name}")
        requested = re.findall(r"@onready var \w+:[^=]+= \$([^\n]+)", script_text)
        missing = [path.strip() for path in requested if path.strip() not in paths]
        self.assertEqual(missing, [])

    def test_multiview_assets_have_alpha(self) -> None:
        from PIL import Image

        root = ROOT / "project/assets/atac_views"
        for slug in ("alba", "barbatos", "barazaph"):
            for view in ("front", "side", "back", "three_quarter"):
                image = Image.open(root / slug / f"{view}.png")
                self.assertEqual(image.mode, "RGBA")
                low, high = image.getchannel("A").getextrema()
                self.assertEqual(low, 0)
                self.assertEqual(high, 255)


if __name__ == "__main__":
    unittest.main()
