#!/usr/bin/env python3
"""Convert visual-style BMP assets into PNGs that keep their transparency.

Qt's BMP loader ignores 32-bit alpha and color keys, so each .bmp is written
to a sibling .png. Transparency comes from the alpha channel, or from the
TransparentColor in the theme INI. When a bitmap is marked transparent but
the INI gives no color, magenta (#ff00ff) is used, which is Luna's usual key.
"""

import argparse
import struct
import sys
import zlib
from pathlib import Path

MAGENTA = (255, 0, 255)


def parse_bool(value):
    if value is None:
        return None
    text = value.strip().lower()
    if text in ("true", "1", "yes"):
        return True
    if text in ("false", "0", "no"):
        return False
    return None


def parse_color(value):
    if not value:
        return None
    parts = value.replace(",", " ").split()
    if len(parts) < 3:
        return None
    try:
        return tuple(int(parts[i]) for i in range(3))
    except ValueError:
        return None


def resource_name(image_file):
    text = image_file.strip().strip('"').replace("/", "\\")
    folder, _, filename = text.rpartition("\\")
    stem = Path(filename).stem
    if folder:
        return f"{folder}_{stem}_BMP".upper()
    return f"{stem}_BMP".upper()


def load_color_keys(root):
    """Map a bitmap stem to ('color', rgb), ('magenta',), or ('none',)."""
    keys = {}
    rank = {"color": 3, "magenta": 2, "none": 1}

    def assign(image_file, transparent, color):
        if transparent is None and color is None:
            return
        if transparent is False:
            policy = ("none",)
        elif color is not None:
            policy = ("color", color)
        elif transparent:
            policy = ("magenta",)
        else:
            return
        name = resource_name(image_file)
        current = keys.get(name)
        if current is None or rank[policy[0]] >= rank[current[0]]:
            keys[name] = policy

    for path in root.rglob("*.ini"):
        section = {}
        for raw in path.read_text(errors="replace").splitlines():
            line = raw.split(";", 1)[0].strip()
            if not line:
                continue
            if line.startswith("[") and line.endswith("]"):
                flush_section(section, assign)
                section = {}
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            section[key.strip().lower()] = value.strip()
        flush_section(section, assign)
    return keys


def flush_section(section, assign):
    if not section:
        return
    transparent = parse_bool(section.get("transparent"))
    color = parse_color(section.get("transparentcolor"))
    glyph_transparent = parse_bool(section.get("glyphtransparent"))
    for key, value in section.items():
        if key.startswith("imagefile"):
            assign(value, transparent, color)
        elif key.startswith("glyphimagefile"):
            assign(value, glyph_transparent, color)


def decode_bmp(data):
    if data[:2] != b"BM":
        raise ValueError("not a BMP")
    pixel_offset = struct.unpack_from("<I", data, 10)[0]
    header_size = struct.unpack_from("<I", data, 14)[0]
    width, raw_height = struct.unpack_from("<ii", data, 18)
    top_down = raw_height < 0
    height = abs(raw_height)
    planes, bpp = struct.unpack_from("<HH", data, 26)
    compression = struct.unpack_from("<I", data, 30)[0]
    colors_used = struct.unpack_from("<I", data, 46)[0] if header_size >= 40 else 0
    if width <= 0 or height <= 0 or planes != 1:
        raise ValueError(f"unsupported geometry {width}x{height}")

    if bpp <= 8:
        count = colors_used or (1 << bpp)
        palette_at = 14 + header_size
        palette = []
        for index in range(count):
            entry = palette_at + index * 4
            blue, green, red = data[entry:entry + 3]
            palette.append((red, green, blue))
    else:
        palette = None

    if compression == 0:
        rows = decode_uncompressed(data, pixel_offset, width, height, bpp, palette, top_down)
    elif compression == 2 and bpp == 4:
        rows = decode_rle4(data, pixel_offset, width, height, palette)
    else:
        raise ValueError(f"unsupported encoding bpp={bpp} compression={compression}")
    return width, height, rows


def decode_uncompressed(data, offset, width, height, bpp, palette, top_down):
    stride = ((width * bpp + 31) // 32) * 4
    rows = []
    for y in range(height):
        src_y = y if top_down else height - 1 - y
        row = data[offset + src_y * stride:offset + (src_y + 1) * stride]
        pixels = []
        if bpp == 32:
            for x in range(width):
                blue, green, red, alpha = row[x * 4:(x + 1) * 4]
                pixels.append((red, green, blue, alpha))
        elif bpp == 24:
            for x in range(width):
                blue, green, red = row[x * 3:x * 3 + 3]
                pixels.append((red, green, blue, 255))
        elif bpp == 8:
            pixels = [(*palette[row[x]], 255) for x in range(width)]
        elif bpp == 4:
            for x in range(width):
                byte = row[x // 2]
                index = (byte >> 4) if x % 2 == 0 else (byte & 0x0F)
                pixels.append((*palette[index], 255))
        elif bpp == 1:
            for x in range(width):
                index = (row[x // 8] >> (7 - (x % 8))) & 1
                pixels.append((*palette[index], 255))
        else:
            raise ValueError(f"unsupported bit depth {bpp}")
        rows.append(pixels)
    return rows


def decode_rle4(data, offset, width, height, palette):
    rows = [[(0, 0, 0, 0) for _ in range(width)] for _ in range(height)]
    x = 0
    y = height - 1
    cursor = offset
    end = len(data)

    def put(index):
        nonlocal x
        if 0 <= x < width and 0 <= y < height and index < len(palette):
            rows[y][x] = (*palette[index], 255)
        x += 1

    while cursor + 1 < end and y >= 0:
        count = data[cursor]
        value = data[cursor + 1]
        cursor += 2
        if count > 0:
            for i in range(count):
                put((value >> 4) if i % 2 == 0 else (value & 0x0F))
            continue
        if value == 0:
            x = 0
            y -= 1
        elif value == 1:
            break
        elif value == 2:
            if cursor + 1 >= end:
                break
            x += data[cursor]
            y -= data[cursor + 1]
            cursor += 2
        else:
            byte_count = (value + 1) // 2
            padded = byte_count + (byte_count & 1)
            encoded = data[cursor:cursor + byte_count]
            cursor += padded
            for i in range(value):
                byte = encoded[i // 2]
                put((byte >> 4) if i % 2 == 0 else (byte & 0x0F))
    return rows


def apply_key(rows, color):
    if color is None:
        return 0
    keyed = 0
    for row in rows:
        for index, pixel in enumerate(row):
            if pixel[:3] == color:
                row[index] = (pixel[0], pixel[1], pixel[2], 0)
                keyed += 1
    return keyed


def contains_color(rows, color):
    return any(pixel[:3] == color for row in rows for pixel in row)


def write_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for red, green, blue, alpha in row:
            raw.extend((red, green, blue, alpha))

    def chunk(tag, payload):
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def color_key_for(stem, keys, rows):
    policy = keys.get(stem.upper())
    if policy is None:
        return MAGENTA if contains_color(rows, MAGENTA) else None
    if policy[0] == "none":
        return None
    if policy[0] == "color":
        return policy[1]
    return MAGENTA


def convert_tree(root):
    keys = load_color_keys(root)
    converted = 0
    keyed = 0
    failed = []
    bitmaps = list(root.rglob("*.bmp")) + list(root.rglob("*.BMP"))
    seen = set()
    for path in bitmaps:
        if path in seen:
            continue
        seen.add(path)
        try:
            width, height, rows = decode_bmp(path.read_bytes())
            color = color_key_for(path.stem, keys, rows)
            keyed += apply_key(rows, color)
            write_png(path.with_suffix(".png"), width, height, rows)
            converted += 1
        except (OSError, ValueError, struct.error) as error:
            failed.append(f"{path}: {error}")
    return converted, keyed, failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root",
        nargs="?",
        type=Path,
        help="theme directory to scan (default: QuickXP/themes next to this repo)",
    )
    args = parser.parse_args()
    root = args.root
    if root is None:
        root = Path(__file__).resolve().parents[1] / "QuickXP" / "themes"
    root = root.resolve()
    if not root.is_dir():
        print(f"not a directory: {root}", file=sys.stderr)
        return 1

    converted, keyed_pixels, failed = convert_tree(root)
    print(f"converted {converted} bitmaps in {root}")
    print(f"keyed {keyed_pixels} transparent pixels")
    for message in failed:
        print(message, file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
