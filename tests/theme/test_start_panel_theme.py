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
    assert panel["leftColumnWidth"] > 0
    assert panel["rightColumnWidth"] > 0
    assert panel["userBarHeight"] > 0
    assert panel["footerHeight"] > 0
