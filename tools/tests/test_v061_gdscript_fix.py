from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class TestV061GDScriptFix(unittest.TestCase):
    def test_multiview_angle_uses_typed_float_and_absf(self):
        text = (ROOT / "project/scripts/multiview_atac.gd").read_text(encoding="utf-8")
        self.assertIn("var angle: float =", text)
        self.assertIn("var absolute_angle: float = absf(angle)", text)
        self.assertNotIn("var absolute_angle := abs(angle)", text)

    def test_multiview_factory_has_typed_root(self):
        text = (ROOT / "project/scripts/atac_factory.gd").read_text(encoding="utf-8")
        self.assertIn("var root: MultiViewAtac = MultiViewAtac.new()", text)


if __name__ == "__main__":
    unittest.main()
