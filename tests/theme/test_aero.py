"""Aero property-store decode and Vista projection."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

from aero_fixture import (
    TINY_PNG,
    atlas_png,
    atlas_rect,
    cmap_bytes,
    margins,
    minimal_variant,
    prop_record,
    write_msstyles,
)
from quickxp_theme import aero_binary, aero_project, detect, pipeline

VISTA_PACK = Path("/home/davidf/virtshare/Vista Default theme/aero.theme")
VISTA_MSSTYLES = VISTA_PACK.parent / "Aero" / "aero.msstyles"


def test_variant_round_trip_button_image_margins_color():
    names = ["Button", "TaskBar", "StartMiddle::Button"]
    variant = aero_binary.parse_variant(minimal_variant(), names)
    image = aero_binary.lookup(variant, ["Button"], 1, "IMAGEFILE")
    margins = aero_binary.lookup(variant, ["Button"], 1, "SIZINGMARGINS")
    color = aero_binary.lookup(variant, ["Button"], 1, "TEXTCOLOR")
    assert image is not None and image.value == 10
    assert margins is not None and margins.value == (4, 5, 6, 7)
    assert color is not None and color.value == "#112233"
    assert aero_binary.parse_cmap(cmap_bytes(names)) == names


def test_import_minimal_vista_fixture(tmp_path: Path):
    style = write_msstyles(tmp_path / "aero.msstyles", version="6.0.6001.18000")
    info = detect.detect(style)
    assert info["generation"] == "vista"
    result = pipeline.import_theme(style, tmp_path / "themes", name="Windows Aero", slug="aero")
    assert result["ok"], result
    assert result["generation"] == "vista"
    doc = json.loads((Path(result["path"]) / "theme.json").read_text(encoding="utf-8"))
    assert doc["generation"] == "vista"
    assert doc["images"]["buttonImage"].endswith("10.png")
    assert doc["images"]["taskbarImage"].endswith("11.png")
    assert doc["images"]["startButtonImage"].endswith("12.png")
    assert doc["button"]["borderLeft"] == 4
    assert doc["button"]["borderTop"] == 6
    assert doc["activeScheme"] == "NormalColor"
    assert (Path(result["path"]) / doc["images"]["buttonImage"]).is_file()


def test_import_win7_parses_then_refuses(tmp_path: Path):
    style = write_msstyles(tmp_path / "aero.msstyles", version="6.1.7600.16385")
    info = detect.detect(style)
    assert info["generation"] == "win7"
    result = pipeline.import_theme(style, tmp_path / "themes")
    assert not result["ok"]
    assert result.get("parsedClasses", 0) > 0
    assert any("Win7 map is not implemented" in err for err in result["errors"])


@pytest.mark.skipif(not VISTA_MSSTYLES.is_file(), reason="Vista Default theme pack is not on this machine")
def test_project_stock_vista_pack(tmp_path: Path):
    result = pipeline.import_theme(
        VISTA_PACK,
        tmp_path / "themes",
        name="Windows Aero",
        slug="aero",
    )
    assert result["ok"], result
    doc = json.loads((Path(result["path"]) / "theme.json").read_text(encoding="utf-8"))
    images = doc["images"]
    assert doc["generation"] == "vista"
    for key in ("buttonImage", "taskbarImage", "startButtonImage", "captionImage"):
        assert key in images, images.keys()
        assert (Path(result["path"]) / images[key]).is_file()
    assert doc["colors"]["glass"] == "#409EFE"
    assert doc["colors"]["glassAlpha"] == "69"
    assert doc["colors"]["taskbar"] == "#409EFE"
    assert doc["colors"]["titleActive"] == "#409EFE"
    assert doc["caption"]["captionMarginLeft"] == 4
    assert doc["caption"]["captionMarginRight"] == 3
    assert doc["caption"]["captionMarginTop"] == 0
    assert doc["caption"]["templateContentLeft"] == 18
    assert doc["caption"]["templateContentTop"] == 8
    assert doc["caption"]["textGlowSize"] == 12
    assert doc["caption"]["glowColor"] == "#FFFFFF"
    assert doc["dwmWindow"]["activeOpacity"] == 80
    assert doc["dwmWindow"]["activeColorizationOpacity"] == 100
    assert doc["sizes"]["sizingBorderWidth"] == 1
    assert doc["sizes"]["paddedBorderWidth"] == 4
    assert doc["sizes"]["captionBarWidth"] == 19
    assert doc["sizes"]["smallCaptionBarWidth"] == 17
    assert doc["sizes"]["smallCaptionBarHeight"] == 17
    parts = doc["dwmWindow"]["parts"]
    assert doc["dwmWindow"]["roles"]["reflection"] == 40
    assert doc["dwmWindow"]["roles"]["titleGlow"] == 56
    assert parts["40"]["width"] == 802 and parts["40"]["height"] == 604
    assert parts["56"]["width"] == 52 and parts["56"]["height"] == 40
    for part in ("3", "4", "5", "6"):
        assert parts[part]["width"] == 28 and parts[part]["height"] == 80
    for part in ("7", "8", "9"):
        assert parts[part]["width"] == 46 and parts[part]["height"] == 80
    assert parts["10"]["width"] == 45 and parts["10"]["height"] == 80
    assert (Path(result["path"]) / parts["40"]["image"]).is_file()
    assert doc["activeScheme"] == "NormalColor"
    assert doc["fonts"]["ui"] == "Segoe UI"


def test_project_caption_metrics_come_from_the_loaded_style(tmp_path: Path):
    """A different style's margins and glow must not be replaced with Vista Default."""
    names = [
        "Button",
        "TaskBar",
        "StartMiddle::Button",
        "Window",
        "CompositedWindow::Window",
        "DWMWindow",
        "globals",
        "sysmetrics",
    ]
    extra = [
        prop_record(3603, 205, 3, 1, payload=margins(9, 8, 1, 2)),
        prop_record(3602, 205, 3, 30, payload=margins(11, 14, 6, 0)),
        prop_record(3001, 206, 3, 30, short=13),
        prop_record(2425, 202, 4, 0, payload=struct.pack("<i", 7)),
        prop_record(2429, 202, 4, 0, payload=struct.pack("<i", 40)),
        prop_record(3816, 204, 4, 0, payload=bytes((3, 2, 1, 0))),
        prop_record(2204, 203, 4, 0, short=1),
        prop_record(3803, 204, 4, 1, state=1, payload=bytes((0x33, 0x22, 0x11, 0))),
        prop_record(3803, 204, 4, 1, state=2, payload=bytes((0x66, 0x55, 0x44, 0))),
        prop_record(3402, 208, 3, 0, payload=struct.pack("<2i", 2, -3)),
        prop_record(2425, 202, 6, 0, payload=struct.pack("<i", 99)),
        prop_record(3816, 204, 6, 0, payload=bytes((255, 255, 255, 0))),
        prop_record(2431, 202, 6, 0, payload=struct.pack("<i", 0x20ABCDEF)),
        prop_record(2430, 202, 5, 7, state=1, payload=struct.pack("<i", 40)),
        prop_record(2432, 202, 5, 7, state=1, payload=struct.pack("<i", 50)),
        prop_record(2430, 202, 5, 7, state=2, payload=struct.pack("<i", 15)),
        prop_record(2432, 202, 5, 7, state=2, payload=struct.pack("<i", 25)),
        prop_record(3602, 205, 5, 7, payload=margins(3, 0, 0, 0)),
        prop_record(2430, 202, 5, 3, state=1, payload=struct.pack("<i", 10)),
        prop_record(2432, 202, 5, 3, state=1, payload=struct.pack("<i", 10)),
        prop_record(1610, 204, 7, 0, payload=bytes((0, 0, 0, 0))),
    ]
    parsed = aero_binary.parse_variant(minimal_variant() + b"".join(extra), names)
    parsed.resource_name = "NORMAL"
    style = aero_binary.AeroFile(
        class_names=names,
        vmap=["Normal", "NormalColor"],
        variants=[parsed],
        images={10: TINY_PNG, 11: TINY_PNG, 12: TINY_PNG, 13: TINY_PNG},
    )
    doc, _warnings, errors = aero_project.project_style(
        style, tmp_path / "theme", name="Custom", generation="vista"
    )
    assert not errors, errors
    caption = doc["caption"]
    assert caption["captionMarginLeft"] == 9
    assert caption["captionMarginRight"] == 8
    assert caption["captionMarginTop"] == 1
    assert caption["templateContentLeft"] == 11
    assert caption["templateContentRight"] == 14
    assert caption["templateContentTop"] == 6
    assert caption["textGlowSize"] == 7
    assert caption["glowIntensity"] == 40
    assert caption["glowColor"] == "#010203"
    assert caption["textShadowOffsetX"] == 2
    assert caption["textShadowOffsetY"] == -3
    assert caption["composited"] is True
    assert doc["colors"]["glass"] == "#ABCDEF"
    assert doc["colors"]["glassAlpha"] == "32"
    assert doc["colors"]["titleActiveText"] == "#112233"
    assert doc["colors"]["titleInactiveText"] == "#445566"
    assert doc["dwmWindow"]["platePart"] == 7
    assert doc["dwmWindow"]["activeOpacity"] == 40
    assert doc["dwmWindow"]["activeColorizationOpacity"] == 50
    assert doc["dwmWindow"]["inactiveOpacity"] == 15
    assert "39" not in doc["dwmWindow"]["parts"]


def test_dwm_atlas_parts_are_cropped_to_the_loaded_rect(tmp_path: Path):
    from mini_pe import build_pe

    sheet = atlas_png(8, 8, (9, 8, 7, 255))
    names = [
        "Button",
        "TaskBar",
        "StartMiddle::Button",
        "DWMWindow",
        "sysmetrics",
    ]
    variant = minimal_variant() + b"".join(
        [
            prop_record(213, 213, 3, 0, short=850),
            prop_record(8002, 209, 3, 4, payload=atlas_rect(1, 2, 5, 6)),
            prop_record(2401, 202, 3, 4, payload=struct.pack("<i", 1)),
            prop_record(3601, 205, 3, 4, payload=margins(1, 2, 3, 4)),
            prop_record(3602, 205, 3, 4, payload=margins(5, 6, 7, 8)),
            prop_record(1201, 202, 4, 0, payload=struct.pack("<i", 2)),
            prop_record(1210, 202, 4, 0, payload=struct.pack("<i", 3)),
            prop_record(1205, 202, 4, 0, payload=struct.pack("<i", 11)),
        ]
    )
    style_path = tmp_path / "aero.msstyles"
    style_path.write_bytes(
        build_pe(
            [
                ("CMAP", "CMAP", cmap_bytes(names)),
                ("VMAP", "VMAP", struct.pack("<I", 0)),
                ("VARIANT", "NORMAL", variant),
                ("IMAGE", 10, TINY_PNG),
                ("IMAGE", 11, TINY_PNG),
                ("IMAGE", 12, TINY_PNG),
                ("STREAM", 850, sheet),
            ]
        )
    )
    loaded = aero_binary.load(style_path)
    assert 850 in loaded.streams
    atlas = aero_binary.lookup(loaded.variant(), ["DWMWindow"], 0, "ATLASIMAGE")
    assert atlas is not None and atlas.value == 850
    rect = aero_binary.lookup(loaded.variant(), ["DWMWindow"], 4, "ATLASRECT")
    assert rect is not None and rect.value == (1, 2, 5, 6)
    doc, _warnings, errors = aero_project.project_style(
        loaded,
        tmp_path / "theme",
        name="Fixture",
        generation="vista",
        colorization="#ABCDEF",
        colorization_alpha=32,
    )
    assert not errors, errors
    part = doc["dwmWindow"]["parts"]["4"]
    assert part["width"] == 4 and part["height"] == 4
    assert part["sizingMargins"] == [1, 2, 3, 4]
    assert part["contentMargins"] == [5, 6, 7, 8]
    assert part["imageCount"] == 1
    assert (tmp_path / "theme" / part["image"]).is_file()
    assert doc["sizes"]["sizingBorderWidth"] == 2
    assert doc["sizes"]["paddedBorderWidth"] == 3
    assert doc["sizes"]["captionBarHeight"] == 11
    assert doc["colors"]["glassAlpha"] == "32"


def test_theme_sidecar_keeps_colorization_alpha(tmp_path: Path):
    path = tmp_path / "aero.theme"
    path.write_text("[VisualStyles]\nColorizationColor=0x45409efe\n", encoding="utf-8")
    meta = aero_project.parse_theme_sidecar(path)
    assert meta["colorization"] == "#409EFE"
    assert meta["colorizationAlpha"] == "69"
