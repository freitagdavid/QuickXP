#!/usr/bin/env python3
"""Extract images and settings from a Windows XP visual style.

An .msstyles file, and the Shellstyle.dll files next to it, are PE DLLs.
The settings are text resources. The images are bitmap resources stored as
DIBs, which have no BITMAPFILEHEADER until this script adds one.

Usage:
    python extract_xp_theme.py [PATH] [-o OUTPUT]

PATH is a theme directory, an .msstyles file, or a Shellstyle.dll.
The default PATH is the current directory. OUTPUT defaults to ./extracted
under PATH (or beside PATH, when PATH is a file).
"""

import argparse
import struct
import sys
from pathlib import Path

RT_BITMAP = 2
RT_STRING = 6
RT_VERSION = 16

TEXT_TYPES = {"TEXTFILE", "UIFILE"}


def find_inputs(path, output):
    if path.is_file():
        return [path], path.parent
    files = []
    for candidate in path.rglob("*"):
        if not candidate.is_file():
            continue
        if output in candidate.parents:
            continue
        name = candidate.name.lower()
        if name.endswith(".msstyles") or name == "shellstyle.dll":
            files.append(candidate)
    return sorted(files), path


def iter_resources(data):
    if data[:2] != b"MZ":
        raise ValueError("not a PE file")
    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    if data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        raise ValueError("not a PE file")
    coff = e_lfanew + 4
    _, nsections, _, _, _, opt_size, _ = struct.unpack_from("<HHIIIHH", data, coff)
    opt = coff + 20
    magic = struct.unpack_from("<H", data, opt)[0]
    # Resource table is data directory 2.
    dd_offset = opt + (112 if magic == 0x20B else 96)
    res_rva, res_size = struct.unpack_from("<II", data, dd_offset + 8 * 2)
    if res_rva == 0 or res_size == 0:
        return

    sections = []
    sec_off = opt + opt_size
    for i in range(nsections):
        off = sec_off + i * 40
        vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", data, off + 8)
        sections.append((va, max(vsize, rawsize), rawptr))

    def rva_to_off(rva):
        for va, span, rawptr in sections:
            if va <= rva < va + span:
                return rawptr + (rva - va)
        raise ValueError(f"RVA {rva:#x} is outside the section table")

    def walk(rva, parts):
        off = rva_to_off(rva)
        _, _, _, _, named_count, id_count = struct.unpack_from("<IIHHHH", data, off)
        base = off + 16
        for i in range(named_count + id_count):
            name_or_id, entry = struct.unpack_from("<II", data, base + i * 8)
            if name_or_id & 0x80000000:
                name_off = rva_to_off(res_rva + (name_or_id & 0x7FFFFFFF))
                nlen = struct.unpack_from("<H", data, name_off)[0]
                name = data[name_off + 2:name_off + 2 + nlen * 2].decode("utf-16le")
            else:
                name = name_or_id
            child = res_rva + (entry & 0x7FFFFFFF)
            ident = parts + [name]
            if entry & 0x80000000:
                yield from walk(child, ident)
            else:
                data_rva, size, _ = struct.unpack_from("<III", data, rva_to_off(child))
                blob_off = rva_to_off(data_rva)
                yield ident, data[blob_off:blob_off + size]

    yield from walk(res_rva, [])


def dib_to_bmp(dib):
    """Prepend a BITMAPFILEHEADER. The resource itself is only the DIB."""
    if len(dib) < 16:
        raise ValueError("bitmap resource is too small")
    header_size = struct.unpack_from("<I", dib, 0)[0]
    if header_size == 12:
        _, _, _, bitcount = struct.unpack_from("<HHHH", dib, 4)
        ncolors = 0 if bitcount > 8 else (1 << bitcount)
        pixels_at = 12 + ncolors * 3
    elif header_size >= 40:
        _, _, _, bitcount, compression, _, _, _, clr_used, _ = struct.unpack_from(
            "<iiHHIIiiII", dib, 4
        )
        if bitcount <= 8:
            palette = (clr_used or (1 << bitcount)) * 4
        elif compression == 3 and header_size == 40:  # BI_BITFIELDS
            palette = 12
        elif compression == 6 and header_size == 40:  # BI_ALPHABITFIELDS
            palette = 16
        else:
            palette = clr_used * 4
        pixels_at = header_size + palette
    else:
        raise ValueError(f"unknown DIB header size {header_size}")
    if pixels_at > len(dib):
        raise ValueError("bitmap palette overruns the resource")
    file_header = struct.pack("<2sIHHI", b"BM", 14 + len(dib), 0, 0, 14 + pixels_at)
    return file_header + dib


def dib_info(dib):
    header_size = struct.unpack_from("<I", dib, 0)[0]
    if header_size == 12:
        _, _, _, bitcount = struct.unpack_from("<HHHH", dib, 4)
        return bitcount
    _, _, _, bitcount, _, _, _, _, _, _ = struct.unpack_from("<iiHHIIiiII", dib, 4)
    return bitcount


def image_extension(blob):
    if blob.startswith((b"GIF87a", b"GIF89a")):
        return ".gif"
    if blob.startswith(b"\x89PNG\r\n\x1a\n"):
        return ".png"
    if blob.startswith(b"\xff\xd8\xff"):
        return ".jpg"
    if blob.startswith(b"BM"):
        return ".bmp"
    return None


def decode_text(blob):
    if len(blob) >= 4 and len(blob) % 2 == 0 and blob[1::2].count(0) / (len(blob) // 2) > 0.5:
        text = blob.decode("utf-16le", errors="replace")
    else:
        try:
            text = blob.decode("utf-8")
        except UnicodeDecodeError:
            text = blob.decode("cp1252", errors="replace")
    parts = [part for part in text.split("\x00") if part]
    if not parts:
        return None
    joined = "\n".join(parts) if len(parts) > 1 else parts[0]
    visible = sum(ch.isprintable() or ch in "\r\n\t" for ch in joined)
    if visible / len(joined) < 0.9:
        return None
    return joined.replace("\r\n", "\n").replace("\r", "\n")


def decode_string_block(blob, block_id):
    base = (int(block_id) - 1) * 16
    found = []
    pos = 0
    for index in range(16):
        if pos + 2 > len(blob):
            break
        length = struct.unpack_from("<H", blob, pos)[0]
        pos += 2
        text = blob[pos:pos + length * 2].decode("utf-16le", errors="replace")
        pos += length * 2
        if text:
            found.append(f"{base + index}\t{text}")
    return found


def safe_name(name):
    text = str(name).replace("\\", "_").replace("/", "_")
    cleaned = "".join("_" if ch in '<>:"|?*' or ord(ch) < 32 else ch for ch in text)
    return cleaned.strip(" .") or "resource"


def unique_path(directory, filename):
    path = directory / filename
    if not path.exists():
        return path
    stem, dot, suffix = filename.rpartition(".")
    if not dot:
        stem, suffix = filename, ""
    else:
        suffix = "." + suffix
    for n in range(2, 1000):
        candidate = directory / f"{stem}-{n}{suffix}"
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"too many files named {filename}")


def settings_filename(restype, name):
    if restype == "TEXTFILE":
        stem = str(name)
        if stem.upper().endswith("_INI"):
            stem = stem[:-4]
        return safe_name(stem) + ".ini"
    if restype == "UIFILE":
        return f"uifile-{safe_name(name)}.txt"
    if isinstance(name, str) and "." in name:
        return safe_name(name)
    if name in (1, "1"):
        return f"{safe_name(restype)}.txt"
    return f"{safe_name(restype)}-{safe_name(name)}.txt"


def extract_file(src, dest):
    resources = list(iter_resources(src.read_bytes()))
    image_dir = dest / "images"
    settings_dir = dest / "settings"
    images = 0
    settings = 0
    alpha_images = 0
    strings = []

    for ident, blob in resources:
        restype = ident[0]
        name = ident[1] if len(ident) > 1 else "resource"
        if restype == RT_VERSION:
            continue
        if restype == RT_STRING:
            strings.extend(decode_string_block(blob, name))
            continue

        ext = image_extension(blob)
        if restype == RT_BITMAP or ext:
            image_dir.mkdir(parents=True, exist_ok=True)
            if restype == RT_BITMAP and ext is None:
                try:
                    payload = dib_to_bmp(blob)
                    if dib_info(blob) == 32:
                        alpha_images += 1
                    filename = safe_name(name) + ".bmp"
                except (ValueError, struct.error):
                    payload = blob
                    filename = safe_name(name) + ".bin"
            else:
                payload = blob
                filename = safe_name(name)
                if not filename.lower().endswith(ext):
                    filename += ext
            unique_path(image_dir, filename).write_bytes(payload)
            images += 1
            continue

        text = None
        if isinstance(restype, str) or restype == 23:
            text = decode_text(blob)
        settings_dir.mkdir(parents=True, exist_ok=True)
        if text is None:
            filename = f"{safe_name(restype)}-{safe_name(name)}.bin"
            unique_path(settings_dir, filename).write_bytes(blob)
        else:
            filename = settings_filename(restype if isinstance(restype, str) else "html", name)
            if restype == 23 and "." not in str(name):
                filename = f"html-{safe_name(name)}.txt"
            unique_path(settings_dir, filename).write_text(text, encoding="utf-8")
        settings += 1

    if strings:
        settings_dir.mkdir(parents=True, exist_ok=True)
        body = "\n".join(strings) + "\n"
        unique_path(settings_dir, "strings.txt").write_text(body, encoding="utf-8")
        settings += 1

    return images, settings, alpha_images


def main():
    parser = argparse.ArgumentParser(description="Extract images and settings from a Windows XP visual style.")
    parser.add_argument("path", nargs="?", default=".", help="theme directory, .msstyles, or Shellstyle.dll")
    parser.add_argument("-o", "--output", help="destination directory (default: extracted next to the input)")
    args = parser.parse_args()

    source = Path(args.path).resolve()
    if not source.exists():
        print(f"nothing at {source}", file=sys.stderr)
        return 1
    output = Path(args.output).resolve() if args.output else (
        source / "extracted" if source.is_dir() else source.parent / "extracted"
    )
    files, root = find_inputs(source, output)
    if not files:
        print(f"no .msstyles or Shellstyle.dll under {source}", file=sys.stderr)
        return 1

    total_images = 0
    total_settings = 0
    for src in files:
        rel_parent = src.parent.relative_to(root)
        dest = output / rel_parent / src.stem
        images, settings, alpha_images = extract_file(src, dest)
        total_images += images
        total_settings += settings
        print(f"{src.relative_to(root) if src.is_relative_to(root) else src.name}: {images} images, {settings} settings -> {dest}")
        if alpha_images:
            print(f"  {alpha_images} images are 32-bit. The top byte is alpha; most BMP viewers ignore it.")
    print(f"{total_images} images and {total_settings} settings in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
