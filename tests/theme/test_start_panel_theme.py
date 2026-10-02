"""Luna STARTPANEL keys required for XP dual-column Start (#69)."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "QuickXP" / "themes" / "luna" / "theme.json"

REQUIRED_IMAGES = [
    "startUserPanelImage",
    "startUserTileImage",
    "startPanelMfuBackgroundImage",
    "startPanelPlacesBackgroundImage",
    "startPanelMoreProgBackgroundImage",
    "startPanelMoreProgArrowImage",
    "startPanelMoreProgArrowHotImage",
    "startPanelLogoffBackgroundImage",
    "startPanelLogoffButtonsImage",
    "startPanelLogoffButtonsHotImage",
    "startPanelProgramsSeparatorImage",
    "startPanelPlacesSeparatorImage",
    "startGroupBackgroundImage",
]

REQUIRED_PANEL_KEYS = [
    "placesFill",
    "mfuFill",
    "logoffFill",
    "placesText",
    "mfuText",
    "placesBorderLeft",
    "mfuBorderLeft",
    "userBorderLeft",
    "logoffBorderLeft",
    "tileContentLeft",
    "tileContentRight",
    "tileContentTop",
    "tileContentBottom",
    "tileBorderLeft",
    "bodyHeight",
    "userBarHeight",
    "footerHeight",
]


def test_start_panel_image_keys_and_files_exist() -> None:
    data = json.loads(THEME.read_text(encoding="utf-8"))
    images = data["images"]
    theme_dir = THEME.parent
    for key in REQUIRED_IMAGES:
        assert key in images, f"missing theme image key {key}"
        rel = images[key]
        path = theme_dir / rel
        assert path.is_file(), f"missing asset for {key}: {path}"


def test_start_panel_sizing_group() -> None:
    data = json.loads(THEME.read_text(encoding="utf-8"))
    panel = data["startPanel"]
    for key in REQUIRED_PANEL_KEYS:
        assert key in panel, f"missing startPanel.{key}"
    assert panel["leftColumnWidth"] > 0
    assert panel["rightColumnWidth"] > 0
    assert panel["userBarHeight"] > 0
    assert panel["footerHeight"] > 0
    assert panel["bodyHeight"] > 0
    # Faces are solid FillColorHint colors (not stretched bitmap gradients).
    assert panel["placesFill"].startswith("#")
    assert panel["mfuFill"].startswith("#")
    # Places list must fit above the logoff strip (Luna: 64+336+40=440).
    assert panel["userBarHeight"] + panel["bodyHeight"] + panel["footerHeight"] <= panel.get(
        "height", 440
    ) + 2


def test_start_group_flyout_chrome() -> None:
    data = json.loads(THEME.read_text(encoding="utf-8"))
    group = data["startGroup"]
    assert group["fill"].startswith("#")
    assert group["borderLeft"] > 0
    assert data["images"]["startGroupBackgroundImage"]
