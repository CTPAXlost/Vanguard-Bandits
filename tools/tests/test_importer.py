import importlib.util
import struct
import sys
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "import_original.py"
spec = importlib.util.spec_from_file_location("vb_importer", MODULE_PATH)
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
assert spec.loader is not None
spec.loader.exec_module(mod)


class ImporterTests(unittest.TestCase):
    def test_classify_tim(self):
        kind, note = mod.classify_block(b"\x10\x00\x00\x00\x02\x00\x00\x00", 32)
        self.assertEqual(kind, "TIM")
        self.assertIn("flags", note)

    def test_probe_tmd_header(self):
        data = struct.pack("<III", 0x41, 0, 1) + struct.pack("<IIIIIII", 12, 4, 20, 4, 28, 2, 0)
        probe = mod.probe_tmd(data)
        self.assertEqual(probe["object_count"], 1)
        self.assertEqual(probe["objects"][0]["vertex_count"], 4)

    @unittest.skipIf(mod.Image is None, "Pillow not installed")
    def test_decode_16bpp_tim(self):
        # Standard TIM header, no CLUT, 16 bpp, 2x1 pixels.
        header = struct.pack("<II", 0x10, 0x02)
        image_block = struct.pack("<IHHHH", 16, 0, 0, 2, 1)
        pixels = struct.pack("<HH", 0x001F, 0x7C00)
        outputs = mod.decode_tim(header + image_block + pixels)
        self.assertEqual(len(outputs), 1)
        _, image = outputs[0]
        self.assertEqual(image.size, (2, 1))
        values = list(image.getdata())
        self.assertGreater(values[0][0], 200)
        self.assertGreater(values[1][2], 200)

    def test_split_reader(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            parts = []
            for index, data in enumerate((b"abc", b"defg", b"hi"), 1):
                path = root / f"disc.mdf.{index:03d}"
                path.write_bytes(data)
                parts.append(path)
            reader = mod.SplitReader(parts)
            try:
                self.assertEqual(reader.read_at(2, 6), b"cdefgh")
            finally:
                reader.close()


if __name__ == "__main__":
    unittest.main()
