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
