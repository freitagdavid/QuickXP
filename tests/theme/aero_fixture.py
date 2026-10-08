"""Hand-built Aero property-store fixtures (no Microsoft theme bytes)."""

from __future__ import annotations

import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from mini_pe import build_pe

TINY_PNG = (
    b"\x89PNG\r\n\x1a\n"
    b"\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
    b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
)


def cmap_bytes(names: list[str]) -> bytes:
    out = bytearray()
    for name in names:
        out.extend((name + "\x00").encode("utf-16le"))
        if len(out) % 8:
            out.extend(b"\x00" * (8 - (len(out) % 8)))
    return bytes(out)


def prop_record(
    name_id: int,
    type_id: int,
    class_id: int,
    part: int,
    state: int = 0,
    short: int = 0,
    payload: bytes = b"",
) -> bytes:
    size = 0 if short else len(payload)
    header = struct.pack("<8i", name_id, type_id, class_id, part, state, short, 0, size)
    if short:
        return header
    blob = header + payload
    pad = (8 - (len(blob) % 8)) % 8
    return blob + b"\x00" * pad


def margins(left: int, right: int, top: int, bottom: int) -> bytes:
    return struct.pack("<4i", left, right, top, bottom)


def atlas_rect(left: int, top: int, right: int, bottom: int) -> bytes:
    """TMT_RECT is left, top, right, bottom. Margins stay left, right, top, bottom."""
    return struct.pack("<4i", left, top, right, bottom)


def atlas_png(width: int, height: int, rgba: tuple[int, int, int, int] = (10, 20, 30, 255)) -> bytes:
    from io import BytesIO

    from PIL import Image

    buf = BytesIO()
    Image.new("RGBA", (width, height), rgba).save(buf, format="PNG")
    return buf.getvalue()


def bgra(red: int, green: int, blue: int) -> bytes:
    return bytes((blue, green, red, 0))


def minimal_variant() -> bytes:
    """Button image + margins + color, taskbar image, start image."""
    parts = [
        prop_record(3001, 206, 0, 1, short=10),
        prop_record(3601, 205, 0, 1, payload=margins(4, 5, 6, 7)),
        prop_record(3803, 204, 0, 1, payload=bgra(0x11, 0x22, 0x33)),
        prop_record(2401, 202, 0, 1, payload=struct.pack("<i", 6)),
        prop_record(3001, 206, 1, 1, short=11),
        prop_record(3002, 206, 2, 0, short=12),
        prop_record(2401, 202, 2, 0, payload=struct.pack("<i", 3)),
    ]
    return b"".join(parts)


def write_msstyles(path: Path, *, version: str = "6.0.6001.18000") -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    version_blob = f"FileVersion\x00{version}\x00".encode("utf-16le")
    path.write_bytes(
        build_pe(
            [
                ("CMAP", "CMAP", cmap_bytes(["Button", "TaskBar", "StartMiddle::Button"])),
                ("VMAP", "VMAP", _vmap(["Normal", "NormalSize", "NormalColor"])),
                ("VARIANT", "NORMAL", minimal_variant()),
                ("IMAGE", 10, TINY_PNG),
                ("IMAGE", 11, TINY_PNG),
                ("IMAGE", 12, TINY_PNG),
                (16, 1, version_blob),
            ]
        )
    )
    return path


def _vmap(names: list[str]) -> bytes:
    out = bytearray()
    for name in names:
        encoded = (name + "\x00").encode("utf-16le")
        count = len(encoded) // 2
        out.extend(struct.pack("<I", count))
        out.extend(encoded)
        if len(out) % 4:
            out.extend(b"\x00" * (4 - (len(out) % 4)))
    return bytes(out)
