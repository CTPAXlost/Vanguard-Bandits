#!/usr/bin/env python3
"""Export original Vanguard Bandits ATAC geometry to Godot-friendly OBJ assets.

The game stores each ATAC as a TIM texture block followed by a custom container
with an embedded TMD at offset 0x10 and a small hierarchical pose section.
This module reconstructs the neutral pose, decodes the model palettes and
writes an OBJ/MTL pair plus metadata. It intentionally does not touch STELLA.XA.
"""

from __future__ import annotations

import json
import math
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None

TMD_ID = 0x41
MODEL_TMD_OFFSET = 0x10
ATAC_TEXTURE_FIRST_BLOCK = 266
ATAC_COUNT = 35
MODEL_SCALE = 1000.0

ATAC_NAMES = [
    "Ultragunner", "Zulwarn", "TIC-TAC", "Alba", "Serata", "Haizuron",
    "Glaive", "Waiban", "Solarus", "Sarbelas", "Sylpheed", "Korbelan",
    "Sharking", "Einlager", "Botsu 0E", "Barbatos", "Altagrave", "Amphisia",
    "Eigol", "Ratatosk", "Crimson", "Botsu 15", "Rahabor", "Toreadore",
    "Botsu 18", "Roaring Lion", "Flaros", "Vedocorban", "Bahamut", "Yurangol",
    "No. 86", "Dantarius", "Barazaph", "Andoras", "Haurol",
]

# Primitive mode, input words, output words -> name, vertex count, textured.
PRIMITIVES = {
    (0x20, 3, 4): ("F3", 3, False),
    (0x24, 5, 7): ("FT3", 3, True),
    (0x28, 4, 5): ("F4", 4, False),
    (0x2C, 7, 9): ("FT4", 4, True),
    (0x30, 4, 6): ("G3", 3, False),
    (0x34, 6, 9): ("GT3", 3, True),
    (0x38, 5, 8): ("G4", 4, False),
    (0x3C, 8, 12): ("GT4", 4, True),
}


class ModelExportError(RuntimeError):
    pass


@dataclass
class Primitive:
    object_index: int
    kind: str
    vertex_indices: list[int]
    uvs: list[tuple[int, int]] | None
    clut: int | None
    tpage: int | None
    color: tuple[int, int, int]


@dataclass
class SkeletonPose:
    offset: int
    bone_count: int
    frame_or_pose_count: int
    parents: list[int]
    translations: list[tuple[int, int, int]]
    rotations: list[tuple[int, int, int]]


def slugify(name: str) -> str:
    text = name.lower().replace(".", "").replace("-", "_").replace(" ", "_")
    return "".join(ch for ch in text if ch.isalnum() or ch == "_")


def psx_color(value: int) -> tuple[int, int, int, int]:
    r = (value & 0x1F) * 255 // 31
    g = ((value >> 5) & 0x1F) * 255 // 31
    b = ((value >> 10) & 0x1F) * 255 // 31
    alpha = 0 if value == 0 else 255
    return r, g, b, alpha


def decode_clut(value: int) -> tuple[int, int]:
    return (value & 0x3F) * 16, (value >> 6) & 0x1FF


def decode_tpage(value: int) -> tuple[int, int, int]:
    # GPU texture page: X in 64-word units, Y in 256-line units, texture depth.
    x = (value & 0x0F) * 64
    y = ((value >> 4) & 0x01) * 256
    depth = (value >> 7) & 0x03
    return x, y, depth


def _rx(angle: float) -> list[list[float]]:
    c, s = math.cos(angle), math.sin(angle)
    return [[1.0, 0.0, 0.0], [0.0, c, -s], [0.0, s, c]]


def _ry(angle: float) -> list[list[float]]:
    c, s = math.cos(angle), math.sin(angle)
    return [[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]]


def _rz(angle: float) -> list[list[float]]:
    c, s = math.cos(angle), math.sin(angle)
    return [[c, -s, 0.0], [s, c, 0.0], [0.0, 0.0, 1.0]]


def _mat_mul(a: Sequence[Sequence[float]], b: Sequence[Sequence[float]]) -> list[list[float]]:
    return [[sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3)] for r in range(3)]


def _mat_vec(a: Sequence[Sequence[float]], v: Sequence[float]) -> tuple[float, float, float]:
    return tuple(sum(a[r][k] * v[k] for k in range(3)) for r in range(3))  # type: ignore[return-value]


def _vec_add(a: Sequence[float], b: Sequence[float]) -> tuple[float, float, float]:
    return a[0] + b[0], a[1] + b[1], a[2] + b[2]


def _rot_matrix(rotation: Sequence[int]) -> list[list[float]]:
    # Psy-Q RotMatrix uses Z -> Y -> X. With column vectors this is Rz*Ry*Rx.
    ax, ay, az = (value * math.tau / 4096.0 for value in rotation)
    return _mat_mul(_mat_mul(_rz(az), _ry(ay)), _rx(ax))


def parse_tmd_container(data: bytes) -> tuple[list[tuple[int, int, int]], list[Primitive], list[tuple[int, ...]], int]:
    base = MODEL_TMD_OFFSET if len(data) >= MODEL_TMD_OFFSET + 12 and struct.unpack_from("<I", data, MODEL_TMD_OFFSET)[0] == TMD_ID else 0
    if len(data) < base + 12 or struct.unpack_from("<I", data, base)[0] != TMD_ID:
        raise ModelExportError("В контейнере не найден TMD 0x41")

    flags, object_count = struct.unpack_from("<II", data, base + 4)
    if flags != 0 or not 1 <= object_count <= 256:
        raise ModelExportError(f"Некорректный TMD: flags={flags}, objects={object_count}")

    objects = [struct.unpack_from("<7I", data, base + 12 + index * 28) for index in range(object_count)]
    vertex_offset, vertex_count = objects[0][0], objects[0][1]
    vertices = [struct.unpack_from("<4h", data, base + vertex_offset + index * 8)[:3] for index in range(vertex_count)]

    primitives: list[Primitive] = []
    for object_index, obj in enumerate(objects):
        # Vanguard Bandits stores a 12-byte attachment record immediately before
        # the packet stream. The stream itself can overlap the next record.
        pos = base + obj[4] + 12
        for primitive_index in range(obj[5]):
            if pos + 4 > len(data):
                raise ModelExportError(f"Обрезан primitive {object_index}:{primitive_index}")
            olen, ilen, flag, mode = struct.unpack_from("4B", data, pos)
            payload = data[pos + 4 : pos + 4 + ilen * 4]
            descriptor = PRIMITIVES.get((mode, ilen, olen))
            if flag != 0 or descriptor is None:
                raise ModelExportError(
                    f"Неизвестный primitive {object_index}:{primitive_index}: mode=0x{mode:02X}, ilen={ilen}, olen={olen}, flag={flag}"
                )
            kind, count, textured = descriptor
            if textured:
                uvs = [(payload[index * 4], payload[index * 4 + 1]) for index in range(count)]
                clut = struct.unpack_from("<H", payload, 2)[0]
                tpage = struct.unpack_from("<H", payload, 6)[0]
                cursor = count * 4
                if kind.startswith("F"):
                    cursor += 2  # shared normal index
                    indices = [struct.unpack_from("<H", payload, cursor + index * 2)[0] for index in range(count)]
                else:
                    indices = [struct.unpack_from("<HH", payload, cursor + index * 4)[1] for index in range(count)]
                color = (255, 255, 255)
            else:
                uvs, clut, tpage = None, None, None
                color = tuple(payload[:3])  # type: ignore[assignment]
                cursor = 4
                if kind.startswith("F"):
                    cursor += 2
                    indices = [struct.unpack_from("<H", payload, cursor + index * 2)[0] for index in range(count)]
                else:
                    indices = [struct.unpack_from("<HH", payload, cursor + index * 4)[1] for index in range(count)]
            if any(index >= vertex_count for index in indices):
                raise ModelExportError(f"Primitive {object_index}:{primitive_index} ссылается за пределы vertex table")
            primitives.append(Primitive(object_index, kind, indices, uvs, clut, tpage, color))
            pos += 4 + ilen * 4
    return vertices, primitives, objects, base


def find_skeleton_pose(data: bytes, objects: Sequence[tuple[int, ...]], base: int) -> SkeletonPose:
    normal_offset, normal_count = objects[0][2], objects[0][3]
    search_start = base + normal_offset + normal_count * 8
    search_end = min(len(data) - 64, search_start + 0x3000)
    for pos in range(search_start, search_end, 2):
        bone_count, frame_count, zero_a, zero_b = struct.unpack_from("<4H", data, pos)
        if not (1 <= bone_count <= min(len(objects), 128)) or frame_count == 0 or zero_a != 0 or zero_b != 0:
            continue
        parents = [struct.unpack_from("<h", data, pos + 8 + index * 2)[0] for index in range(bone_count)]
        if parents[0] != -1:
            continue
        if any(parent < -1 or parent >= index for index, parent in enumerate(parents) if index > 0):
            continue
        cursor = pos + 8 + bone_count * 2
        required = cursor + bone_count * 12
        if required > len(data):
            continue
        translations = [struct.unpack_from("<3h", data, cursor + index * 6) for index in range(bone_count)]
        cursor += bone_count * 6
        rotations = [struct.unpack_from("<3h", data, cursor + index * 6) for index in range(bone_count)]
        return SkeletonPose(pos, bone_count, frame_count, parents, translations, rotations)
    raise ModelExportError("Не найдена иерархическая нейтральная поза ATAC")


def build_global_pose(pose: SkeletonPose) -> tuple[list[tuple[float, float, float]], list[list[list[float]]]]:
    positions: list[tuple[float, float, float]] = [(0.0, 0.0, 0.0)] * pose.bone_count
    rotations: list[list[list[float]]] = [[[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]] for _ in range(pose.bone_count)]
    for index in range(pose.bone_count):
        local_rotation = _rot_matrix(pose.rotations[index])
        local_translation = pose.translations[index]
        parent = pose.parents[index]
        if parent < 0:
            positions[index] = tuple(float(v) for v in local_translation)
            rotations[index] = local_rotation
        else:
            positions[index] = _vec_add(positions[parent], _mat_vec(rotations[parent], local_translation))
            rotations[index] = _mat_mul(rotations[parent], local_rotation)
    return positions, rotations


@dataclass
class ModelTexture:
    image_x: int
    image_y: int
    width: int
    height: int
    palettes: dict[tuple[int, int], "Image.Image"]


def decode_model_tim(data: bytes) -> ModelTexture:
    if Image is None:
        raise ModelExportError("Для текстур установите Pillow")
    if len(data) < 20 or data[:4] != b"\x10\x00\x00\x00":
        raise ModelExportError("Парный блок не является TIM")
    flags = struct.unpack_from("<I", data, 4)[0]
    if not flags & 8:
        raise ModelExportError("TIM модели без CLUT")
    clut_size, clut_x, clut_y, clut_w, clut_h = struct.unpack_from("<IHHHH", data, 8)
    raw_colors = data[20 : 8 + clut_size]
    colors = [psx_color(value[0]) for value in struct.iter_unpack("<H", raw_colors)]
    image_pos = 8 + clut_size
    image_size, image_x, image_y, width_words, height = struct.unpack_from("<IHHHH", data, image_pos)
    raw_pixels = data[image_pos + 12 : image_pos + image_size]

    # These model TIMs advertise mode 1 but are laid out as 4bpp: 64 VRAM
    # words become 256 texture pixels and the TMD packets select 16-color CLUTs.
    width = width_words * 4
    indices: list[int] = []
    for byte in raw_pixels[: width_words * 2 * height]:
        indices.extend((byte & 0x0F, (byte >> 4) & 0x0F))
    indices = indices[: width * height]

    palettes: dict[tuple[int, int], Image.Image] = {}
    row_width = clut_w
    for row in range(clut_h):
        row_colors = colors[row * row_width : (row + 1) * row_width]
        for column in range(0, row_width, 16):
            palette = (row_colors[column : column + 16] + [(0, 0, 0, 0)] * 16)[:16]
            rgba = [palette[index] for index in indices]
            image = Image.new("RGBA", (width, height))
            image.putdata(rgba)
            palettes[(clut_x + column, clut_y + row)] = image
    return ModelTexture(image_x, image_y, width, height, palettes)


def _triangles(count: int) -> list[tuple[int, int, int]]:
    return [(0, 1, 2)] if count == 3 else [(0, 1, 2), (0, 2, 3)]


def _object_world_bounds(
    object_index: int,
    vertices: Sequence[tuple[int, int, int]],
    primitives: Sequence[Primitive],
    positions: Sequence[tuple[float, float, float]],
    rotations: Sequence[Sequence[Sequence[float]]],
) -> tuple[list[float], list[float]] | None:
    points: list[tuple[float, float, float]] = []
    for primitive in primitives:
        if primitive.object_index != object_index:
            continue
        for vertex_index in primitive.vertex_indices:
            local = vertices[vertex_index]
            points.append(_vec_add(positions[object_index], _mat_vec(rotations[object_index], local)))
    if not points:
        return None
    mins = [min(point[axis] for point in points) for axis in range(3)]
    maxs = [max(point[axis] for point in points) for axis in range(3)]
    return mins, maxs


def _split_body_and_attachments(
    vertices: Sequence[tuple[int, int, int]],
    primitives: Sequence[Primitive],
    pose: SkeletonPose,
    positions: Sequence[tuple[float, float, float]],
    rotations: Sequence[Sequence[Sequence[float]]],
    object_count: int,
) -> tuple[list[int], list[int]]:
    """Separate the neutral ATAC body from hand-held weapon/effect objects.

    In all confirmed Vanguard Bandits ATAC containers the final hierarchical
    object is parented to the right-hand chain and has a dramatically larger
    span than the armour parts. The remaining TMD objects after the hierarchy
    are weapon/effect variants. Keeping them out of the body OBJ prevents a
    mismatched weapon from floating through the restored model while still
    documenting every attachment for the next weapon-selection stage.
    """
    body = list(range(pose.bone_count))
    attachments = list(range(pose.bone_count, object_count))
    if pose.bone_count > 1:
        candidate = pose.bone_count - 1
        bounds = _object_world_bounds(candidate, vertices, primitives, positions, rotations)
        if bounds is not None:
            mins, maxs = bounds
            maximum_span = max(maxs[axis] - mins[axis] for axis in range(3))
            # Body armour parts are below ~800 source units in the confirmed
            # models; hand-held weapons are 1200+ and parented into an arm.
            if maximum_span >= 900.0 and pose.parents[candidate] >= 0:
                body.remove(candidate)
                attachments.insert(0, candidate)
    return body, attachments


def export_atac_model(
    texture_data: bytes,
    model_data: bytes,
    output_dir: Path,
    atac_id: int,
    atac_name: str,
    texture_block: int,
    model_block: int,
) -> dict:
    vertices, primitives, objects, base = parse_tmd_container(model_data)
    pose = find_skeleton_pose(model_data, objects, base)
    positions, rotations = build_global_pose(pose)
    texture = decode_model_tim(texture_data)
    body_object_indices, attachment_object_indices = _split_body_and_attachments(
        vertices, primitives, pose, positions, rotations, len(objects)
    )
    body_object_set = set(body_object_indices)

    slug = slugify(atac_name)
    target = output_dir / slug
    textures_dir = target / "textures"
    target.mkdir(parents=True, exist_ok=True)
    textures_dir.mkdir(parents=True, exist_ok=True)

    # Save only palettes actually addressed by this model and present in its TIM.
    used_cluts = {decode_clut(p.clut) for p in primitives if p.clut is not None}
    palette_files: dict[tuple[int, int], str] = {}
    for coord in sorted(used_cluts, key=lambda item: (item[1], item[0])):
        image = texture.palettes.get(coord)
        if image is None:
            continue
        filename = f"palette_{coord[0]:03d}_{coord[1]:03d}.png"
        image.save(textures_dir / filename)
        palette_files[coord] = f"textures/{filename}"

    # Assemble the first N TMD objects through the discovered bone hierarchy.
    # Extra TMD objects are weapon variants/effects and are recorded separately.
    transformed: dict[tuple[int, int], tuple[float, float, float]] = {}
    model_points: list[tuple[float, float, float]] = []
    for primitive in primitives:
        if primitive.object_index not in body_object_set:
            continue
        for vertex_index in primitive.vertex_indices:
            key = primitive.object_index, vertex_index
            if key in transformed:
                continue
            local = vertices[vertex_index]
            world = _vec_add(positions[primitive.object_index], _mat_vec(rotations[primitive.object_index], local))
            transformed[key] = world
            model_points.append(world)
    if not model_points:
        raise ModelExportError("В модели не найдено отображаемых полигонов")

    min_x = min(point[0] for point in model_points)
    max_x = max(point[0] for point in model_points)
    min_y = min(point[1] for point in model_points)
    max_y = max(point[1] for point in model_points)
    min_z = min(point[2] for point in model_points)
    max_z = max(point[2] for point in model_points)
    center_x = (min_x + max_x) / 2.0
    center_z = (min_z + max_z) / 2.0
    # PSX Y points down in the source pose; Godot Y points up.
    floor_y = -max_y

    mtl_lines = [f"# {atac_name} materials reconstructed from original TIM"]
    for coord, relative in sorted(palette_files.items(), key=lambda item: (item[0][1], item[0][0])):
        material = f"clut_{coord[0]:03d}_{coord[1]:03d}"
        mtl_lines += [f"newmtl {material}", "Ka 1.000 1.000 1.000", "Kd 1.000 1.000 1.000", "Ks 0.000 0.000 0.000", "d 1.000", f"map_Kd {relative}", ""]
    mtl_lines += ["newmtl external_texture", "Ka 0.350 0.350 0.420", "Kd 0.650 0.680 0.760", "Ks 0.000 0.000 0.000", "d 1.000", ""]

    color_materials: dict[tuple[int, int, int], str] = {}
    for primitive in primitives:
        if primitive.uvs is None and primitive.object_index in body_object_set:
            color_materials.setdefault(primitive.color, f"rgb_{primitive.color[0]:03d}_{primitive.color[1]:03d}_{primitive.color[2]:03d}")
    for color, material in sorted(color_materials.items()):
        r, g, b = (component / 255.0 for component in color)
        mtl_lines += [f"newmtl {material}", f"Ka {r:.6f} {g:.6f} {b:.6f}", f"Kd {r:.6f} {g:.6f} {b:.6f}", "Ks 0.000 0.000 0.000", "d 1.000", ""]

    obj_lines = [f"# Original Vanguard Bandits ATAC {atac_name}", f"mtllib {slug}.mtl", f"o {slug}"]
    vertex_number = 0
    uv_number = 0
    face_count = 0
    current_group = None
    current_material = None

    for primitive in primitives:
        if primitive.object_index not in body_object_set:
            continue
        if current_group != primitive.object_index:
            current_group = primitive.object_index
            obj_lines.append(f"g bone_{current_group:02d}")
        coord = decode_clut(primitive.clut) if primitive.clut is not None else None
        page = decode_tpage(primitive.tpage) if primitive.tpage is not None else None
        if primitive.uvs is not None and coord in palette_files and page and page[0] == texture.image_x and page[1] == texture.image_y:
            material = f"clut_{coord[0]:03d}_{coord[1]:03d}"
        elif primitive.uvs is not None:
            material = "external_texture"
        else:
            material = color_materials[primitive.color]
        if material != current_material:
            current_material = material
            obj_lines.append(f"usemtl {material}")

        face_vertices: list[int] = []
        face_uvs: list[int | None] = []
        for corner, source_index in enumerate(primitive.vertex_indices):
            point = transformed[(primitive.object_index, source_index)]
            gx = (point[0] - center_x) / MODEL_SCALE
            gy = ((-point[1]) - floor_y) / MODEL_SCALE
            gz = (-(point[2] - center_z)) / MODEL_SCALE
            obj_lines.append(f"v {gx:.7f} {gy:.7f} {gz:.7f}")
            vertex_number += 1
            face_vertices.append(vertex_number)
            if primitive.uvs is not None:
                u, v = primitive.uvs[corner]
                obj_lines.append(f"vt {(u + 0.5) / texture.width:.7f} {1.0 - (v + 0.5) / texture.height:.7f}")
                uv_number += 1
                face_uvs.append(uv_number)
            else:
                face_uvs.append(None)
        for triangle in _triangles(len(primitive.vertex_indices)):
            if primitive.uvs is not None:
                obj_lines.append("f " + " ".join(f"{face_vertices[index]}/{face_uvs[index]}" for index in triangle))
            else:
                obj_lines.append("f " + " ".join(str(face_vertices[index]) for index in triangle))
            face_count += 1

    (target / f"{slug}.obj").write_text("\n".join(obj_lines) + "\n", encoding="utf-8")
    (target / f"{slug}.mtl").write_text("\n".join(mtl_lines) + "\n", encoding="utf-8")

    metadata = {
        "atac_id": atac_id,
        "name": atac_name,
        "slug": slug,
        "texture_block": texture_block,
        "model_block": model_block,
        "tmd_objects": len(objects),
        "bone_count": pose.bone_count,
        "pose_count_hint": pose.frame_or_pose_count,
        "primitive_count": len(primitives),
        "exported_faces": face_count,
        "body_object_indices": body_object_indices,
        "attachment_object_indices": attachment_object_indices,
        "extra_object_indices": list(range(pose.bone_count, len(objects))),
        "skeleton_offset": pose.offset,
        "parents": pose.parents,
        "translations": pose.translations,
        "rotations": pose.rotations,
        "source_bounds": {"min": [min_x, min_y, min_z], "max": [max_x, max_y, max_z]},
        "godot_height": (max_y - min_y) / MODEL_SCALE,
        "materials_with_local_palette": len(palette_files),
        "note": "Static neutral body pose reconstructed from the original TMD hierarchy. Hand-held weapon/effect attachments are listed separately to avoid mismatched equipment; animation streams remain in the source block for the next stage.",
    }
    (target / "model.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return metadata


def export_selected_atacs(blocks_dir: Path, output_dir: Path, atac_ids: Iterable[int] = (3, 4, 6)) -> list[dict]:
    results: list[dict] = []
    for atac_id in atac_ids:
        if not 0 <= atac_id < ATAC_COUNT:
            raise ModelExportError(f"ATAC ID вне диапазона: {atac_id}")
        texture_block = ATAC_TEXTURE_FIRST_BLOCK + atac_id * 2
        model_block = texture_block + 1
        texture_candidates = list(blocks_dir.glob(f"{texture_block:04d}_*.bin"))
        model_candidates = list(blocks_dir.glob(f"{model_block:04d}_*.bin"))
        if len(texture_candidates) != 1 or len(model_candidates) != 1:
            raise ModelExportError(f"Не найдена пара блоков {texture_block}/{model_block}")
        texture_data = texture_candidates[0].read_bytes()
        model_data = model_candidates[0].read_bytes()
        # Dummy/Botsu models do not carry the regular skeleton and are skipped.
        try:
            result = export_atac_model(
                texture_data, model_data, output_dir, atac_id, ATAC_NAMES[atac_id], texture_block, model_block
            )
        except ModelExportError as exc:
            result = {
                "atac_id": atac_id,
                "name": ATAC_NAMES[atac_id],
                "texture_block": texture_block,
                "model_block": model_block,
                "status": "skipped",
                "error": str(exc),
            }
        results.append(result)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "models.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    return results
