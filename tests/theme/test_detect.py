"""Generation detection tests (#25)."""

from __future__ import annotations

from pathlib import Path

from quickxp_theme import detect


def test_detect_luna_extract_tree(luna_theme: Path):
    result = detect.detect(luna_theme)
    assert result["generation"] == "xp"
    assert result["confidence"] >= 0.45
    assert any("ini" in r.lower() or "xp" in r.lower() or "bmp" in r.lower() for r in result["reasons"])


def test_detect_tiny_xp_settings(tmp_path: Path):
    settings = tmp_path / "settings"
    settings.mkdir()
    (settings / "NORMALBLUE.ini").write_text(
        "[button.pushbutton]\nImageFile=Blue\\button.bmp\n[SysMetrics]\nBtnface=1 2 3\n",
        encoding="utf-8",
    )
    images = tmp_path / "images"
    images.mkdir()
    for name in ("BLUE_BUTTON_BMP.bmp", "BLUE_STARTBUTTON_BMP.bmp", "a.bmp", "b.bmp", "c.bmp"):
        (images / name).write_bytes(b"BM")
    result = detect.detect(tmp_path)
    assert result["generation"] == "xp"
    assert result["xp_score"] >= 3


def test_detect_vista_like_png_tree(tmp_path: Path):
    images = tmp_path / "images"
    images.mkdir()
    for i in range(6):
        (images / f"part{i}.png").write_bytes(b"\x89PNG\r\n\x1a\n")
    result = detect.detect(tmp_path)
    assert result["generation"] in ("vista", "unknown")
    assert result["generation"] != "xp" or result["confidence"] < 0.5


def test_detect_missing_path(tmp_path: Path):
    result = detect.detect(tmp_path / "nope")
    assert result["generation"] == "unknown"
    assert result["confidence"] == 0.0
