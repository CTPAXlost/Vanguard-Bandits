#!/usr/bin/env python3
"""Local importer for a legally obtained Vanguard Bandits (SLUS-01070) disc image.

The importer deliberately skips STELLA.XA by default because the remaster project
will not use the original intro videos or streamed music.
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import io
import json
import os
import re
import shutil
import struct
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import BinaryIO, Iterable, Sequence

try:
    from PIL import Image
except ImportError:  # pragma: no cover - handled at runtime
    Image = None

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))
from vb_model_export import export_selected_atacs

LOGICAL_SECTOR = 2048
SUPPORTED_SERIAL = "SLUS-01070"


class ImportErrorVB(RuntimeError):
    pass


class RandomReader:
    size: int

    def read_at(self, offset: int, size: int) -> bytes:
        raise NotImplementedError

    def close(self) -> None:
        pass


class FileReader(RandomReader):
    def __init__(self, path: Path):
        self.path = path
        self._file = path.open("rb")
        self.size = path.stat().st_size

    def read_at(self, offset: int, size: int) -> bytes:
        self._file.seek(offset)
        data = self._file.read(size)
        if len(data) != size:
            raise EOFError(f"Неожиданный конец файла {self.path}")
        return data

    def close(self) -> None:
        self._file.close()


class SplitReader(RandomReader):
    def __init__(self, parts: Sequence[Path]):
        if not parts:
            raise ImportErrorVB("Не найдены части образа")
        self.parts = list(parts)
        self._sizes = [p.stat().st_size for p in self.parts]
        self._starts: list[int] = []
        total = 0
        for size in self._sizes:
            self._starts.append(total)
            total += size
        self.size = total
        self._files: list[BinaryIO] = [p.open("rb") for p in self.parts]

    def read_at(self, offset: int, size: int) -> bytes:
        if offset < 0 or size < 0 or offset + size > self.size:
            raise EOFError("Чтение выходит за границы частей образа")
        out = bytearray()
        remaining = size
        position = offset
        while remaining:
            index = bisect.bisect_right(self._starts, position) - 1
            local = position - self._starts[index]
            take = min(remaining, self._sizes[index] - local)
            f = self._files[index]
            f.seek(local)
            chunk = f.read(take)
            if len(chunk) != take:
                raise EOFError(f"Не удалось прочитать часть {self.parts[index]}")
            out.extend(chunk)
            position += take
            remaining -= take
        return bytes(out)

    def close(self) -> None:
        for f in self._files:
            f.close()


@dataclass(frozen=True)
class ImageMode:
    name: str
    raw_sector_size: int
    user_data_offset: int


@dataclass(frozen=True)
class IsoFile:
    name: str
    lba: int
    size: int
    flags: int


@dataclass
class EpicaBlock:
    index: int
    offset: int
    size: int
    kind: str
    note: str
    sha256: str = ""
    decoded_files: list[str] | None = None
    model_probe: dict | None = None


class DiscImage:
    def __init__(self, reader: RandomReader, display_path: Path):
        self.reader = reader
        self.display_path = display_path
        self.mode = self._detect_mode()
        self.logical_size = (reader.size // self.mode.raw_sector_size) * LOGICAL_SECTOR
        self.files = self._parse_iso_root()
        self.serial = self._detect_serial()

    def close(self) -> None:
        self.reader.close()

    def read_logical(self, offset: int, size: int) -> bytes:
        if offset < 0 or offset + size > self.logical_size:
            raise EOFError("Логическое чтение выходит за границы образа")
        out = bytearray()
        remaining = size
        logical = offset
        while remaining:
            sector = logical // LOGICAL_SECTOR
            within = logical % LOGICAL_SECTOR
            take = min(remaining, LOGICAL_SECTOR - within)
            physical = (
                sector * self.mode.raw_sector_size
                + self.mode.user_data_offset
                + within
            )
            out.extend(self.reader.read_at(physical, take))
            logical += take
            remaining -= take
        return bytes(out)

    def read_file(self, entry: IsoFile) -> bytes:
        return self.read_logical(entry.lba * LOGICAL_SECTOR, entry.size)

    def extract_file(self, entry: IsoFile, target: Path) -> None:
        target.parent.mkdir(parents=True, exist_ok=True)
        remaining = entry.size
        logical = entry.lba * LOGICAL_SECTOR
        with target.open("wb") as out:
            while remaining:
                take = min(1 << 20, remaining)
                out.write(self.read_logical(logical, take))
                logical += take
                remaining -= take

    def _detect_mode(self) -> ImageMode:
        modes = [
            ImageMode("ISO 2048", 2048, 0),
            ImageMode("MDF 2448", 2448, 24),
            ImageMode("RAW 2352", 2352, 24),
        ]
        for mode in modes:
            if self.reader.size < mode.raw_sector_size * 20:
                continue
            if self.reader.size % mode.raw_sector_size:
                continue
            offset = 16 * mode.raw_sector_size + mode.user_data_offset
            pvd = self.reader.read_at(offset, LOGICAL_SECTOR)
            if pvd[:7] == b"\x01CD001\x01":
                return mode
        raise ImportErrorVB("Не удалось определить ISO/MDF/RAW формат образа")

    def _parse_iso_root(self) -> dict[str, IsoFile]:
        pvd = self.read_logical(16 * LOGICAL_SECTOR, LOGICAL_SECTOR)
        if pvd[:7] != b"\x01CD001\x01":
            raise ImportErrorVB("Некорректная ISO9660 файловая система")
        root = pvd[156:]
        if len(root) < 34 or root[0] < 34:
            raise ImportErrorVB("Не найден корневой каталог ISO9660")
        lba = struct.unpack_from("<I", root, 2)[0]
        size = struct.unpack_from("<I", root, 10)[0]
        directory = self.read_logical(lba * LOGICAL_SECTOR, size)
        result: dict[str, IsoFile] = {}
        pos = 0
        while pos < len(directory):
            length = directory[pos]
            if length == 0:
                pos = ((pos // LOGICAL_SECTOR) + 1) * LOGICAL_SECTOR
                continue
            record = directory[pos : pos + length]
            if len(record) < 34:
                break
            name_len = record[32]
            raw_name = record[33 : 33 + name_len]
            if raw_name not in (b"\x00", b"\x01"):
                name = raw_name.decode("ascii", "replace").split(";")[0].upper()
                result[name] = IsoFile(
                    name=name,
                    lba=struct.unpack_from("<I", record, 2)[0],
                    size=struct.unpack_from("<I", record, 10)[0],
                    flags=record[25],
                )
            pos += length
        return result

    def _detect_serial(self) -> str:
        system = self.files.get("SYSTEM.CNF")
        if not system:
            raise ImportErrorVB("В образе не найден SYSTEM.CNF")
        text = self.read_file(system).decode("ascii", "replace").upper()
        if "SLUS_010.70" in text or "SLUS-01070" in text:
            return SUPPORTED_SERIAL
        raise ImportErrorVB("Поддерживается только Vanguard Bandits SLUS-01070")


def resolve_reader(path: Path) -> tuple[RandomReader, Path, list[Path]]:
    path = path.expanduser().resolve()
    if not path.exists():
        raise ImportErrorVB(f"Файл не найден: {path}")

    if path.suffix.lower() == ".mds":
        base = path.with_suffix("")
        candidates = [base.with_suffix(".mdf"), base.with_suffix(".MDF")]
        mdfs = [p for p in candidates if p.exists()]
        if not mdfs:
            mdfs = list(path.parent.glob("*.mdf"))
        if len(mdfs) != 1:
            raise ImportErrorVB("Рядом с MDS не найден единственный соответствующий MDF")
        path = mdfs[0]

    split_match = re.search(r"\.\d{3}$", path.name)
    if split_match:
        prefix = path.name[:-4]
        parts: list[Path] = []
        index = 1
        while True:
            candidate = path.parent / f"{prefix}.{index:03d}"
            if not candidate.exists():
                break
            parts.append(candidate)
            index += 1
        if not parts:
            raise ImportErrorVB("Не найдены последовательные части .001, .002 ...")
        return SplitReader(parts), path, parts

    # Also accept selecting the unsuffixed MDF when only split volumes exist.
    if not path.exists() and (path.parent / f"{path.name}.001").exists():
        return resolve_reader(path.parent / f"{path.name}.001")

    return FileReader(path), path, [path]


def classify_block(data: bytes, full_size: int) -> tuple[str, str]:
    if len(data) >= 8 and data[:4] == b"\x10\x00\x00\x00":
        flags = struct.unpack_from("<I", data, 4)[0]
        return "TIM", f"PS1 TIM flags=0x{flags:X}"
    if len(data) >= 12 and struct.unpack_from("<I", data, 0)[0] == 0x41:
        return "TMD", "Вероятная стандартная PS1 TMD-модель"
    if len(data) >= 0x1C and struct.unpack_from("<I", data, 0x10)[0] == 0x41:
        return "TMD_ANIM", "Контейнер Vanguard Bandits: TMD + иерархия/анимации"
    if data[:4] == b"RIFF":
        return "RIFF", "Мультимедийный контейнер"
    for marker in (b"MFONT", b"SPSB", b"SPDB_0", b"SPDB_1", b"LOADBUF"):
        if marker in data:
            return "SCRIPT_DATA", f"Маркер {marker.decode('ascii')}"
    printable = sum(1 for b in data if b in (9, 10, 13) or 32 <= b <= 126)
    if data and printable / len(data) > 0.65:
        return "TEXT", ascii_preview(data)
    if full_size % 2048 == 0:
        return "BINARY_SECTOR", "Размер кратен 2048"
    return "BINARY", "Тип ещё не определён"


def ascii_preview(data: bytes, limit: int = 72) -> str:
    chars = []
    was_space = False
    for value in data:
        if 32 <= value <= 126:
            chars.append(chr(value))
            was_space = False
        elif not was_space:
            chars.append(" ")
            was_space = True
        if len(chars) >= limit:
            break
    return "".join(chars).strip()


def psx_color(value: int) -> tuple[int, int, int, int]:
    r = (value & 0x1F) * 255 // 31
    g = ((value >> 5) & 0x1F) * 255 // 31
    b = ((value >> 10) & 0x1F) * 255 // 31
    alpha = 0 if value == 0 else 255
    return r, g, b, alpha


def decode_tim(data: bytes) -> list[tuple[str, "Image.Image"]]:
    if Image is None:
        raise ImportErrorVB("Для декодирования TIM установите Pillow: pip install Pillow")
    if len(data) < 20 or data[:4] != b"\x10\x00\x00\x00":
        raise ImportErrorVB("Блок не является TIM")
    flags = struct.unpack_from("<I", data, 4)[0]
    bpp_mode = flags & 0x7
    has_clut = bool(flags & 0x8)
    pos = 8
    palettes: list[list[tuple[int, int, int, int]]] = []

    if has_clut:
        if pos + 12 > len(data):
            raise ImportErrorVB("Повреждённый CLUT TIM")
        clut_size = struct.unpack_from("<I", data, pos)[0]
        _, _, clut_w, clut_h = struct.unpack_from("<HHHH", data, pos + 4)
        raw_colors = data[pos + 12 : pos + clut_size]
        colors = [psx_color(v[0]) for v in struct.iter_unpack("<H", raw_colors)]
        row_width = max(1, clut_w)
        palettes = [colors[y * row_width : (y + 1) * row_width] for y in range(max(1, clut_h))]
        pos += clut_size

    if pos + 12 > len(data):
        raise ImportErrorVB("Повреждённый блок изображения TIM")
    image_size = struct.unpack_from("<I", data, pos)[0]
    _, _, width_words, height = struct.unpack_from("<HHHH", data, pos + 4)
    pixels = data[pos + 12 : pos + image_size]

    outputs: list[tuple[str, Image.Image]] = []
    if bpp_mode == 0:  # 4 bpp
        width = width_words * 4
        if not palettes:
            raise ImportErrorVB("4bpp TIM без палитры")
        for p_index, palette in enumerate(palettes):
            palette = (palette + [(0, 0, 0, 0)] * 16)[:16]
            rgba: list[tuple[int, int, int, int]] = []
            for byte in pixels[: width_words * 2 * height]:
                rgba.append(palette[byte & 0x0F])
                rgba.append(palette[(byte >> 4) & 0x0F])
            img = Image.new("RGBA", (width, height))
            img.putdata(rgba[: width * height])
            outputs.append((f"p{p_index:02d}", img))
    elif bpp_mode == 1:  # 8 bpp
        width = width_words * 2
        if not palettes:
            raise ImportErrorVB("8bpp TIM без палитры")
        for p_index, palette in enumerate(palettes):
            palette = (palette + [(0, 0, 0, 0)] * 256)[:256]
            rgba = [palette[index] for index in pixels[: width * height]]
            img = Image.new("RGBA", (width, height))
            img.putdata(rgba)
            outputs.append((f"p{p_index:02d}", img))
    elif bpp_mode == 2:  # 16 bpp
        width = width_words
        values = [v[0] for v in struct.iter_unpack("<H", pixels[: width * height * 2])]
        img = Image.new("RGBA", (width, height))
        img.putdata([psx_color(value) for value in values])
        outputs.append(("16bpp", img))
    elif bpp_mode == 3:  # 24 bpp
        width = (width_words * 2) // 3
        expected = width * height * 3
        raw = pixels[:expected]
        rgba = []
        for i in range(0, len(raw) - 2, 3):
            # TIM stores RGB bytes in the same order expected by common decoders.
            rgba.append((raw[i], raw[i + 1], raw[i + 2], 255))
        img = Image.new("RGBA", (width, height))
        img.putdata(rgba[: width * height])
        outputs.append(("24bpp", img))
    else:
        raise ImportErrorVB(f"Неизвестный TIM bpp mode {bpp_mode}")
    return outputs


def probe_tmd(data: bytes) -> dict:
    if len(data) < 12 or struct.unpack_from("<I", data, 0)[0] != 0x41:
        return {}
    flags, object_count = struct.unpack_from("<II", data, 4)
    result: dict = {"flags": flags, "object_count": object_count, "objects": []}
    if object_count > 4096:
        result["warning"] = "Нереалистичное число объектов"
        return result
    table_pos = 12
    for index in range(object_count):
        pos = table_pos + index * 28
        if pos + 28 > len(data):
            result["warning"] = "Таблица объектов обрезана"
            break
        vert_top, vert_count, norm_top, norm_count, prim_top, prim_count, scale = struct.unpack_from(
            "<IIIIIII", data, pos
        )
        result["objects"].append(
            {
                "index": index,
                "vertex_offset": vert_top,
                "vertex_count": vert_count,
                "normal_offset": norm_top,
                "normal_count": norm_count,
                "primitive_offset": prim_top,
                "primitive_count": prim_count,
                "scale": scale,
            }
        )
    return result


def extract_ascii_strings(data: bytes, min_length: int = 4) -> list[str]:
    pattern = re.compile(rb"[\x20-\x7E]{%d,}" % min_length)
    return [match.group().decode("ascii", "replace") for match in pattern.finditer(data)]


def parse_epica(epica_path: Path, blocks_dir: Path, textures_dir: Path, models_dir: Path) -> tuple[list[EpicaBlock], int]:
    epica_size = epica_path.stat().st_size
    with epica_path.open("rb") as f:
        header = f.read(min(epica_size, 0x2000))
        entries: list[tuple[int, int]] = []
        for pos in range(0, len(header) - 7, 8):
            offset, size = struct.unpack_from("<II", header, pos)
            if size == 0:
                break
            if offset < 0x800 or offset + size > epica_size:
                raise ImportErrorVB(f"Некорректный блок EPICA #{pos // 8}: 0x{offset:X}, {size}")
            entries.append((offset, size))

        blocks: list[EpicaBlock] = []
        decoded_count = 0
        for index, (offset, size) in enumerate(entries):
            f.seek(offset)
            data = f.read(size)
            kind, note = classify_block(data[:512], size)
            block_path = blocks_dir / f"{index:04d}_{kind.lower()}.bin"
            block_path.write_bytes(data)
            record = EpicaBlock(
                index=index,
                offset=offset,
                size=size,
                kind=kind,
                note=note,
                sha256=hashlib.sha256(data).hexdigest(),
                decoded_files=[],
            )
            if kind == "TIM":
                try:
                    for suffix, image in decode_tim(data):
                        relative_name = f"epica_{index:04d}_{suffix}.png"
                        image.save(textures_dir / relative_name)
                        record.decoded_files.append(relative_name)
                        decoded_count += 1
                except Exception as exc:  # keep raw block even when an exotic TIM fails
                    record.note += f"; TIM decode error: {exc}"
            elif kind == "TMD":
                probe = probe_tmd(data)
                record.model_probe = probe
                (models_dir / f"epica_{index:04d}.tmd.json").write_text(
                    json.dumps(probe, ensure_ascii=False, indent=2), encoding="utf-8"
                )
            blocks.append(record)
    return blocks, decoded_count


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def run_import(image_path: Path, repo_root: Path, output: Path, include_streams: bool) -> dict:
    reader, resolved, parts = resolve_reader(image_path)
    disc = DiscImage(reader, resolved)
    try:
        if disc.serial != SUPPORTED_SERIAL:
            raise ImportErrorVB("Неверная версия игры")

        original_dir = output / "original"
        blocks_dir = output / "epica" / "blocks"
        research_dir = output / "research"
        textures_dir = repo_root / "project" / "assets" / "imported" / "textures"
        models_dir = repo_root / "project" / "assets" / "imported" / "models"
        for directory in (original_dir, blocks_dir, research_dir, textures_dir, models_dir):
            directory.mkdir(parents=True, exist_ok=True)

        extracted: dict[str, str] = {}
        for name in ("SYSTEM.CNF", "SLUS_010.70", "EPICA.BIN"):
            entry = disc.files.get(name)
            if not entry:
                raise ImportErrorVB(f"В образе отсутствует {name}")
            target = original_dir / name
            disc.extract_file(entry, target)
            try:
                extracted[name] = str(target.relative_to(repo_root))
            except ValueError:
                extracted[name] = str(target)

        if include_streams:
            entry = disc.files.get("STELLA.XA")
            if entry:
                target = original_dir / "STELLA.XA"
                disc.extract_file(entry, target)
                try:
                    extracted["STELLA.XA"] = str(target.relative_to(repo_root))
                except ValueError:
                    extracted["STELLA.XA"] = str(target)

        blocks, decoded_count = parse_epica(
            original_dir / "EPICA.BIN", blocks_dir, textures_dir, models_dir
        )

        # Export the first confirmed original ATAC bodies. The mapping is based
        # on the paired EPICA layout: texture = 266 + ID*2, model = texture+1.
        model_results = export_selected_atacs(blocks_dir, models_dir, (3, 4, 6))
        exported_models = sum(1 for item in model_results if item.get("status") != "skipped")

        slus = (original_dir / "SLUS_010.70").read_bytes()
        epica = (original_dir / "EPICA.BIN").read_bytes()
        strings = sorted(set(extract_ascii_strings(slus) + extract_ascii_strings(epica)))
        (research_dir / "ascii_strings.txt").write_text("\n".join(strings), encoding="utf-8")

        manifest = {
            "serial": disc.serial,
            "image_mode": disc.mode.name,
            "source_name": resolved.name,
            "source_parts": [p.name for p in parts],
            "logical_size": disc.logical_size,
            "files": [asdict(entry) for entry in sorted(disc.files.values(), key=lambda e: e.name)],
            "epica_blocks": [asdict(block) for block in blocks],
            "original_streams_imported": include_streams,
            "exported_atac_models": model_results,
            "policy_note": "STELLA.XA не импортируется по умолчанию: оригинальные ролики и музыка не используются.",
        }
        write_json(output / "manifest.json", manifest)

        report = {
            "serial": disc.serial,
            "image_mode": disc.mode.name,
            "epica_blocks": len(blocks),
            "tim_blocks": sum(1 for b in blocks if b.kind == "TIM"),
            "tmd_blocks": sum(1 for b in blocks if b.kind == "TMD"),
            "tmd_animation_containers": sum(1 for b in blocks if b.kind == "TMD_ANIM"),
            "exported_atac_models": exported_models,
            "text_blocks": sum(1 for b in blocks if b.kind in ("TEXT", "SCRIPT_DATA")),
            "decoded_tim_textures": decoded_count,
            "ascii_strings": len(strings),
            "original_streams_imported": include_streams,
        }
        write_json(repo_root / "project" / "data" / "generated" / "import_report.json", report)
        return report
    finally:
        disc.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Импорт данных Vanguard Bandits SLUS-01070 в проект ремастера"
    )
    parser.add_argument("image", type=Path, help="MDF/MDS/ISO или первая часть .001")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Папка рабочего импорта (по умолчанию workspace/imported)",
    )
    parser.add_argument(
        "--include-streams",
        action="store_true",
        help="Также извлечь STELLA.XA. Для ремастера не рекомендуется.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    repo_root = Path(__file__).resolve().parents[1]
    output = args.output.resolve() if args.output else repo_root / "workspace" / "imported"
    try:
        report = run_import(args.image, repo_root, output, args.include_streams)
    except (ImportErrorVB, OSError, EOFError) as exc:
        print(f"ОШИБКА: {exc}", file=sys.stderr)
        return 1
    print("Импорт завершён:")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print(f"Рабочие файлы: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
