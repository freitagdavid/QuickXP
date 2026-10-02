"""INI → theme.json projector tests (#26)."""

from __future__ import annotations

import json
from pathlib import Path

from quickxp_theme import project, schemes
from quickxp_theme.convert import resource_name


REQUIRED_IMAGES = (
    "buttonImage",
    "taskbarImage",
    "startButtonImage",
    "trayImage",
    "checkBoxImage",
    "tabItemTopImage",
    "comboButtonImage",
    "scrollArrowImage",
)


def test_project_luna_normalblue(luna_theme: Path):
    ini = luna_theme / "luna" / "settings" / "NORMALBLUE.ini"
    assert ini.is_file()
    doc, warnings, errors = project.project_theme(luna_theme, ini, generation="xp")
    assert not errors, errors
    assert doc["generation"] == "xp"
    assert doc["name"] == "Windows XP Luna"
    images = doc["images"]
    for key in REQUIRED_IMAGES:
        assert key in images, f"missing {key}; warnings={warnings}"
        path = luna_theme / images[key]
        assert path.is_file(), images[key]
    assert doc["button"]["frames"] == 5
    assert doc["button"]["borderLeft"] == 8
    assert doc["startButton"]["font"] == "Franklin Gothic Medium"
    assert doc["startButton"]["italic"] is True
    assert doc["startButton"]["frames"] == 3
    assert doc["startButton"]["borderLeft"] == 6
    assert doc["startButton"]["borderRight"] == 52
    assert doc["startButton"]["imageLayout"] == "vertical"
    assert doc["colors"]["taskbar"].startswith("#")
    assert "taskbar" in doc
    assert doc["taskbar"]["borderTop"] >= 0
    # Epic K caption / frame / button assets
    assert "captionImage" in images
    assert images.get("captionActiveImage")
    assert images.get("closeButtonImage")
    assert images.get("closeGlyphImage")
    assert images.get("frameLeftImage")
    assert doc["caption"]["frames"] == 2
    assert doc["sizes"].get("captionBarHeight") == 25
    assert "buttonImage" in images
    assert images["buttonImage"].endswith("BLUE_BUTTON_BMP.png")
    assert "startFlagImage" in images
    assert images["startFlagImage"].endswith("143.png")
    assert doc["startButton"].get("composeFlag") is True
    assert doc["captionButton"].get("offsetTop") == 5


def test_infer_horizontal_start_layout(tmp_path: Path):
    """Candy-style Start buttons are often a wide horizontal strip."""
    from PIL import Image

    png = tmp_path / "start.png"
    Image.new("RGBA", (165, 22), (200, 200, 200, 255)).save(png)
    layout = project.infer_image_layout({}, png, 3)
    assert layout == "horizontal"
    layout_v = project.infer_image_layout({"imagelayout": "vertical"}, png, 3)
    assert layout_v == "vertical"


def test_project_alt_imagefile_names(tmp_path: Path):
    """Tiny extract with non-Luna ImageFile paths still resolves via resource_name."""
    settings = tmp_path / "settings"
    images = tmp_path / "images"
    settings.mkdir()
    images.mkdir()

    # Create minimal PNGs named by convert.resource_name
    mapping = {
        "Skin\\Push.bmp": "buttonImage",
        "Skin\\Bar.bmp": "taskbarImage",
        "Skin\\Start.bmp": "startButtonImage",
    }
    ini_lines = [
        "[SysMetrics]",
        "Btnface = 236 233 216",
        "Background = 58 110 165",
        "Highlight = 49 106 197",
        "ActiveCaption = 0 84 227",
        "CaptionText = 255 255 255",
        "InactiveCaption = 122 150 223",
        "InactiveCaptionText = 216 228 248",
        "HighlightText = 255 255 255",
        "Menu = 255 255 255",
        "WindowText = 12 34 56",
        "BtnText = 78 90 12",
        "MenuText = 34 56 78",
        "ScrollbarWidth = 17",
        "",
        "[button.pushbutton]",
        "ImageFile = Skin\\Push.bmp",
        "SizingMargins = 4, 4, 4, 4",
        "imageCount = 5",
        "",
        "[TaskBar.BackgroundBottom]",
        "ImageFile = Skin\\Bar.bmp",
        "FillColorHint = 36 94 220",
        "",
        "[Start::Button]",
        "ImageFile = Skin\\Start.bmp",
        "ContentMargins = 10, 24, 2, 4",
        "Font = Tahoma, 12",
        "TextColor = 255 255 255",
        "imageCount = 3",
    ]
    (settings / "NORMALBLUE.ini").write_text("\n".join(ini_lines) + "\n", encoding="utf-8")

    # Minimal valid PNG (1x1)
    png = (
        b"\x89PNG\r\n\x1a\n"
        b"\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    for image_file in mapping:
        stem = resource_name(image_file)
        (images / f"{stem}.png").write_bytes(png)

    doc, warnings, errors = project.project_theme(
        tmp_path, settings / "NORMALBLUE.ini", name="Alt Skin", generation="xp"
    )
    assert not errors, errors
    assert doc["images"]["buttonImage"] == "images/SKIN_PUSH_BMP.png"
    assert doc["images"]["taskbarImage"] == "images/SKIN_BAR_BMP.png"
    assert doc["images"]["startButtonImage"] == "images/SKIN_START_BMP.png"
    assert doc["name"] == "Alt Skin"
    assert doc["colors"]["windowText"] == "#0C2238"
    assert doc["colors"]["buttonText"] == "#4E5A0C"
    assert doc["colors"]["menuText"] == "#22384E"


def test_infer_compose_start_flag_truesize():
    assert project.infer_compose_start_flag({"sizingType": "truesize"}) is False
    assert project.infer_compose_start_flag({"contentLeft": -20}) is False
    assert project.infer_compose_start_flag({"fontSize": 1}) is False
    assert project.infer_compose_start_flag({
        "sizingType": "stretch",
        "contentLeft": 10,
        "fontSize": 14,
    }) is True


def test_ensure_start_flag_skips_truesize(tmp_path: Path):
    doc = {
        "images": {},
        "startButton": {"sizingType": "truesize", "composeFlag": False},
    }
    out = project.ensure_start_flag(tmp_path, doc)
    assert "startFlagImage" not in out["images"]


def test_project_sysmetrics_text_colors_default_black(tmp_path: Path):
    """Luna-style SysMetrics omit WindowText/BtnText/MenuText → black defaults."""
    settings = tmp_path / "settings"
    images = tmp_path / "images"
    settings.mkdir()
    images.mkdir()
    (settings / "NORMALBLUE.ini").write_text(
        """
[SysMetrics]
Btnface = 236 233 216
Background = 58 110 165
Highlight = 49 106 197
ActiveCaption = 0 84 227
CaptionText = 255 255 255
Menu = 255 255 255
HighlightText = 255 255 255
ScrollbarWidth = 17

[button.pushbutton]
ImageFile = Skin\\Push.bmp
SizingMargins = 4, 4, 4, 4
imageCount = 5

[TaskBar.BackgroundBottom]
ImageFile = Skin\\Bar.bmp
FillColorHint = 36 94 220

[Start::Button]
ImageFile = Skin\\Start.bmp
ContentMargins = 10, 24, 2, 4
TextColor = 255 255 255
imageCount = 3
""",
        encoding="utf-8",
    )
    png = (
        b"\x89PNG\r\n\x1a\n"
        b"\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    for image_file in ("Skin\\Push.bmp", "Skin\\Bar.bmp", "Skin\\Start.bmp"):
        (images / f"{resource_name(image_file)}.png").write_bytes(png)

    doc, _, errors = project.project_theme(
        tmp_path, settings / "NORMALBLUE.ini", name="No Text Keys", generation="xp"
    )
    assert not errors, errors
    assert doc["colors"]["windowText"] == "#000000"
    assert doc["colors"]["buttonText"] == "#000000"
    assert doc["colors"]["menuText"] == "#000000"
    assert doc["colors"]["button"] == "#ECE9D8"
    assert doc["colors"]["classicMenu"] == "#ECE9D8"
    assert doc["colors"]["buttonFace"] == "#ECE9D8"


def test_list_schemes_luna(luna_theme: Path):
    listed = schemes.list_schemes(luna_theme)
    ids = [s["id"].upper() for s in listed]
    assert "NORMALBLUE" in ids
    assert listed[0]["id"].upper() == "NORMALBLUE"
    assert any(s["label"] == "Blue" for s in listed)


def test_project_writes_json(tmp_path: Path, luna_theme: Path):
    # Copy just enough is heavy; project into a temp copy of paths via symlink-like structure
    # Project against luna and write into tmp by using luna as root (read-only assert via dump)
    ini = luna_theme / "luna" / "settings" / "NORMALBLUE.ini"
    doc, _, errors = project.project_theme(luna_theme, ini)
    assert not errors
    out = tmp_path / "theme.json"
    out.write_text(json.dumps(doc), encoding="utf-8")
    loaded = json.loads(out.read_text(encoding="utf-8"))
    assert loaded["images"]["buttonImage"].endswith(".png")
