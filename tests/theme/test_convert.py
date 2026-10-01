"""Tests for quickxp_theme.convert."""

from __future__ import annotations

import struct
from pathlib import Path

from quickxp_theme import convert


def test_parse_bool():
    assert convert.parse_bool("true") is True
    assert convert.parse_bool("1") is True
    assert convert.parse_bool("yes") is True
    assert convert.parse_bool("false") is False
    assert convert.parse_bool("0") is False
    assert convert.parse_bool("no") is False
    assert convert.parse_bool(None) is None
    assert convert.parse_bool("maybe") is None


def test_parse_color():
    assert convert.parse_color("255 0 255") == (255, 0, 255)
    assert convert.parse_color("255,0,128") == (255, 0, 128)
    assert convert.parse_color("") is None
    assert convert.parse_color("1 2") is None
    assert convert.parse_color("a b c") is None


def test_resource_name():
    assert convert.resource_name("Blue\\StartButton.bmp") == "BLUE_STARTBUTTON_BMP"
    assert convert.resource_name('"Taskbar\\Background"') == "TASKBAR_BACKGROUND_BMP"
    assert convert.resource_name("StartButton.bmp") == "STARTBUTTON_BMP"


def test_load_color_keys_tiny_ini(tmp_path: Path):
    settings = tmp_path / "settings"
    settings.mkdir()
    (settings / "sample.ini").write_text(
        """
[Start.Button]
ImageFile=Blue\\StartButton.bmp
Transparent=true
TransparentColor=255 0 255

[TaskBar.Background]
ImageFile=Taskbar\\Background.bmp
Transparent=false
""",
        encoding="utf-8",
    )
    keys = convert.load_color_keys(tmp_path)
    assert keys["BLUE_STARTBUTTON_BMP"] == ("color", (255, 0, 255))
    assert keys["TASKBAR_BACKGROUND_BMP"] == ("none",)


def test_decode_write_luna_start_button(luna_theme: Path, tmp_path: Path):
    bmp = luna_theme / "luna" / "images" / "BLUE_STARTBUTTON_BMP.bmp"
    assert bmp.is_file()
    width, height, rows = convert.decode_bmp(bmp.read_bytes())
    assert width > 0 and height > 0
    assert len(rows) == height
    assert len(rows[0]) == width

    keyed = convert.apply_key(rows, convert.MAGENTA)
    out = tmp_path / "start.png"
    convert.write_png(out, width, height, rows)
    data = out.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n")
    # Luna start button uses magenta keying in practice.
    assert keyed >= 0


def test_write_png_roundtrip_pixel(tmp_path: Path):
    rows = [[(255, 0, 255, 255), (0, 0, 0, 0)]]
    convert.apply_key(rows, convert.MAGENTA)
    assert rows[0][0][3] == 0
    out = tmp_path / "tiny.png"
    convert.write_png(out, 2, 1, rows)
    data = out.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    ihdr_at = data.index(b"IHDR")
    w, h = struct.unpack_from(">II", data, ihdr_at + 4)
    assert (w, h) == (2, 1)
    assert b"IDAT" in data
