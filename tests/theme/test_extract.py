"""Tests for quickxp_theme.extract."""

from __future__ import annotations

import struct
from pathlib import Path

from quickxp_theme import extract


def _synthetic_dib(width: int = 2, height: int = 2, bpp: int = 24) -> bytes:
    """Minimal BI_RGB DIB (no file header) for dib_to_bmp tests."""
    header_size = 40
    stride = ((width * bpp + 31) // 32) * 4
    pixels = bytes(stride * height)
    dib = struct.pack(
        "<IiiHHIIiiII",
        header_size,
        width,
        height,
        1,  # planes
        bpp,
        0,  # BI_RGB
        len(pixels),
        0,
        0,
        0,
        0,
    )
    assert len(dib) == header_size
    return dib + pixels


def test_safe_name():
    assert extract.safe_name(r"Blue\Start") == "Blue_Start"
    assert extract.safe_name('bad<>:"|?*name') == "bad_______name"
    assert extract.safe_name("   ") == "resource"


def test_settings_filename():
    assert extract.settings_filename("TEXTFILE", "NORMALBLUE_INI") == "NORMALBLUE.ini"
    assert extract.settings_filename("UIFILE", "Main") == "uifile-Main.txt"
    assert extract.settings_filename("TEXTFILE", "COLORSTYLE") == "COLORSTYLE.ini"


def test_dib_to_bmp_and_info():
    dib = _synthetic_dib()
    bmp = extract.dib_to_bmp(dib)
    assert bmp.startswith(b"BM")
    assert extract.dib_info(dib) == 24
    # BITMAPFILEHEADER is 14 bytes
    assert bmp[14:] == dib


def test_find_inputs_file(tmp_path: Path):
    msstyles = tmp_path / "Luna.msstyles"
    msstyles.write_bytes(b"MZ")
    output = tmp_path / "out"
    files, root = extract.find_inputs(msstyles, output)
    assert files == [msstyles]
    assert root == tmp_path


def test_find_inputs_directory(tmp_path: Path):
    theme = tmp_path / "theme"
    theme.mkdir()
    dll = theme / "shellstyle.dll"
    dll.write_bytes(b"MZ")
    nested = theme / "skins"
    nested.mkdir()
    (nested / "Other.msstyles").write_bytes(b"MZ")
    output = tmp_path / "extracted"
    output.mkdir()
    # File inside output tree must be ignored
    (output / "skip.msstyles").write_bytes(b"MZ")

    files, root = extract.find_inputs(theme, output)
    assert root == theme
    names = sorted(p.name.lower() for p in files)
    assert names == ["other.msstyles", "shellstyle.dll"]
