"""Aurorae package emission tests (Epic K)."""

from __future__ import annotations

import json
from pathlib import Path

from quickxp_theme import aurorae, project


def test_aurorae_id():
    assert aurorae.aurorae_id("luna") == "quickxp-luna"
    assert aurorae.aurorae_id("Concave Dark") == "quickxp-concave-dark"


def test_emit_aurorae_luna(luna_theme: Path, tmp_path: Path):
    # Work on a copy so we do not dirty the fixture during projection side-effects.
    import shutil

    work = tmp_path / "luna"
    shutil.copytree(luna_theme, work)
    ini = work / "luna" / "settings" / "NORMALBLUE.ini"
    doc, warnings, errors = project.project_theme(
        work,
        ini,
        generation="xp",
        slug="luna",
        name="Windows XP Luna",
    )
    assert not errors, errors
    assert "captionImage" in doc["images"]
    assert "closeButtonImage" in doc["images"]
    assert "closeGlyphImage" in doc["images"]
    assert "frameLeftImage" in doc["images"]
    assert doc["images"].get("captionActiveImage")
    assert doc["caption"]["frames"] == 2
    project.write_theme_json(work, doc)

    summary, awarnings, aerrors = aurorae.emit_aurorae(work, slug="luna", document=doc)
    assert not aerrors, aerrors
    assert summary["ok"] is True
    assert summary["id"] == "quickxp-luna"
    out = Path(summary["path"])
    assert out.is_dir()
    files = set(summary["files"])
    assert "decoration.svg" in files
    assert "close.svg" in files
    assert "minimize.svg" in files
    assert "maximize.svg" in files
    assert "restore.svg" in files
    assert "metadata.desktop" in files
    assert "quickxp-lunarc" in files

    deco = (out / "decoration.svg").read_text(encoding="utf-8")
    for element in (
        "decoration-top",
        "decoration-topleft",
        "decoration-topright",
        "decoration-left",
        "decoration-right",
        "decoration-bottom",
        "decoration-inactive-top",
    ):
        assert f'id="{element}"' in deco

    close = (out / "close.svg").read_text(encoding="utf-8")
    for element in ("active-center", "hover-center", "pressed-center", "inactive-center"):
        assert f'id="{element}"' in close

    rc = (out / "quickxp-lunarc").read_text(encoding="utf-8")
    assert "TitleHeight=" in rc
    assert "ButtonWidth=" in rc
    assert "ActiveTextColor=" in rc
    # Vertical caption SizingMargins must not inflate restored titlebars.
    assert "TitleEdgeTop=0" in rc
    assert "TitleEdgeBottom=0" in rc
    assert "TitleEdgeTopMaximized=0" in rc
    # Luna: caption frame 29px, CloseButton Offset y=5, button 21 → pad above/below.
    assert "TitleHeight=29" in rc
    assert "ButtonHeight=21" in rc
    assert "ButtonMarginTop=5" in rc

    desktop = (out / "metadata.desktop").read_text(encoding="utf-8")
    assert "X-KDE-PluginInfo-Name=quickxp-luna" in desktop


def test_caption_rc_follows_loaded_theme_metrics(tmp_path: Path):
    """Margins, glow, and frame alpha come from the theme document, not Vista defaults."""
    import base64
    import io

    from PIL import Image

    root = tmp_path / "custom"
    images = root / "images"
    images.mkdir(parents=True)
    caption = Image.new("RGBA", (20, 20), (12, 34, 56, 255))
    caption.putpixel((0, 0), (0, 0, 0, 0))
    caption.save(images / "caption.png")
    doc = {
        "name": "Custom Aero",
        "generation": "vista",
        "images": {"captionImage": "images/caption.png"},
        "colors": {
            "glass": "#112233",
            "glassAlpha": "32",
            "titleActiveText": "#000000",
            "titleInactiveText": "#445566",
        },
        "sizes": {},
        "frame": {},
        "caption": {
            "borderLeft": 4,
            "borderRight": 4,
            "borderTop": 4,
            "borderBottom": 4,
            "captionMarginLeft": 9,
            "captionMarginRight": 8,
            "captionMarginTop": 1,
            "templateContentLeft": 11,
            "templateContentRight": 14,
            "templateContentTop": 6,
            "glowColor": "#010203",
            "textGlowSize": 7,
            "textShadowOffsetX": 2,
            "textShadowOffsetY": -3,
        },
        "dwmWindow": {
            "activeOpacity": 40,
            "activeColorizationOpacity": 50,
            "inactiveOpacity": 15,
            "inactiveColorizationOpacity": 25,
        },
    }
    summary, _warnings, errors = aurorae.emit_aurorae(root, slug="custom", document=doc)
    assert not errors, errors
    rc = (root / "aurorae" / "quickxp-customrc").read_text(encoding="utf-8")
    assert "TitleEdgeLeft=9" in rc
    assert "TitleEdgeRight=8" in rc
    assert "TitleEdgeTop=1" in rc
    assert "ButtonWidthMenu=11" in rc
    assert "ButtonMarginTop=6" in rc
    assert "ButtonHeight=21" in rc
    assert "TitleBorderRight=14" in rc
    assert "TextGlowSize=7" in rc
    assert "ActiveTextShadowColor=1,2,3" in rc
    assert "TextShadowOffsetX=2" in rc
    assert "TextShadowOffsetY=-3" in rc
    assert "TitleBorderLeft=28" not in rc
    deco = (root / "aurorae" / "decoration.svg").read_text(encoding="utf-8")
    encoded = deco.split('id="decoration-topleft-img"', 1)[1].split("base64,", 1)[1].split('"', 1)[0]
    tile = Image.open(io.BytesIO(base64.b64decode(encoded)))
    assert tile.getpixel((0, 0))[3] == 0
    assert tile.getpixel((tile.width - 1, tile.height - 1))[3] == 255
    assert 'id="decoration-top" opacity=' not in deco


def test_narrow_caption_strips_stretch_to_widest_button(tmp_path: Path):
    """Aero min/max art is a sizing slice; Aurorae uses one ButtonWidth for all."""
    from PIL import Image

    root = tmp_path / "aero"
    images = root / "images"
    images.mkdir(parents=True)
    Image.new("RGBA", (40, 20), (20, 40, 80, 255)).save(images / "caption.png")
    Image.new("RGBA", (20, 16), (180, 40, 40, 255)).save(images / "close.png")
    Image.new("RGBA", (4, 16), (40, 160, 180, 255)).save(images / "min.png")
    Image.new("RGBA", (18, 18), (255, 255, 255, 255)).save(images / "glyph.png")
    doc = {
        "name": "Aero",
        "images": {
            "captionImage": "images/caption.png",
            "closeButtonImage": "images/close.png",
            "closeGlyphImage": "images/glyph.png",
            "minButtonImage": "images/min.png",
            "minGlyphImage": "images/glyph.png",
        },
        "caption": {"borderLeft": 4, "borderRight": 4, "borderTop": 2, "borderBottom": 2},
        "captionButton": {
            "frames": 1,
            "borderLeft": 1,
            "borderRight": 1,
            "borderTop": 1,
            "borderBottom": 1,
            "imageLayout": "vertical",
        },
        "colors": {},
        "sizes": {},
        "frame": {},
    }
    summary, _warnings, errors = aurorae.emit_aurorae(root, slug="aero", document=doc)
    assert not errors, errors
    assert summary["ok"] is True
    rc = (root / "aurorae" / "quickxp-aerorc").read_text(encoding="utf-8")
    assert "ButtonWidth=20" in rc
    assert "ButtonHeight=16" in rc
    minimize = (root / "aurorae" / "minimize.svg").read_text(encoding="utf-8")
    assert 'width="20"' in minimize
    assert 'height="16"' in minimize


def test_glass_plate_alpha_uses_loaded_opacities():
    # 69 * 80% * 100% from a loaded colorization dword and DWM opacities.
    assert aurorae.glass_plate_alpha(69, 80, 100) == 55
    assert aurorae.glass_plate_alpha(None, None, None) is None


def test_generate_for_theme_root_luna(luna_theme: Path, tmp_path: Path):
    import shutil

    work = tmp_path / "luna"
    shutil.copytree(luna_theme, work)
    # Start without theme.json caption fields — generate should project + emit.
    if (work / "theme.json").is_file():
        # Keep a minimal stub so generate still finds a root.
        pass
    result = aurorae.generate_for_theme_root(work, slug="luna", ini="NORMALBLUE")
    assert result["ok"], result
    assert (work / "aurorae" / "decoration.svg").is_file()


def test_sync_install_only(tmp_path: Path, luna_theme: Path):
    import shutil
    import sys

    sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "QuickXP" / "services"))
    import sync_aurorae

    work = tmp_path / "luna"
    shutil.copytree(luna_theme, work)
    result = aurorae.generate_for_theme_root(work, slug="luna", ini="NORMALBLUE")
    assert result["ok"], result

    dest = tmp_path / "aurorae-themes"
    installed = sync_aurorae.install_package(work, dest)
    assert installed["ok"], installed
    assert installed["id"] == "quickxp-luna"
    assert (dest / "quickxp-luna" / "decoration.svg").is_file()
    assert (dest / "quickxp-luna" / "quickxp-lunarc").is_file()
