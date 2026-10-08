"""QML decoration packages carry the loaded theme, not Vista Default."""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from aero_fixture import TINY_PNG, atlas_png, atlas_rect, cmap_bytes, margins, minimal_variant, prop_record
from mini_pe import build_pe
from quickxp_theme import aero_binary, aero_project, kdecoration


def test_package_metrics_follow_the_fixture_not_vista_default(tmp_path: Path):
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
            prop_record(8002, 209, 3, 9, payload=atlas_rect(0, 0, 4, 4)),
            prop_record(2401, 202, 3, 9, payload=struct.pack("<i", 1)),
            prop_record(3601, 205, 3, 9, payload=margins(1, 1, 1, 1)),
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
                ("VARIANT", "NORMAL", variant),
                ("IMAGE", 10, TINY_PNG),
                ("IMAGE", 11, TINY_PNG),
                ("IMAGE", 12, TINY_PNG),
                ("STREAM", 850, atlas_png(8, 8)),
            ]
        )
    )
    loaded = aero_binary.load(style_path)
    root = tmp_path / "theme"
    doc, _warnings, errors = aero_project.project_style(
        loaded,
        root,
        name="Fixture Glass",
        generation="vista",
        colorization="#ABCDEF",
        colorization_alpha=32,
    )
    assert not errors, errors
    summary, warnings, kdeco_errors = kdecoration.emit_kdecoration(root, slug="fixture", document=doc)
    assert not kdeco_errors, kdeco_errors
    assert not warnings
    assert summary["ok"] is True
    assert summary["id"] == "kwin4_decoration_qml_quickxp_fixture"
    package = root / "kdecoration"
    assert (package / "metadata.json").is_file()
    assert (package / "contents" / "ui" / "main.qml").is_file()
    assert (package / "contents" / "ui" / "CaptionButton.qml").is_file()
    assert (package / "contents" / "ui" / "images" / "9.png").is_file()
    meta = json.loads((package / "metadata.json").read_text(encoding="utf-8"))
    assert meta["KPlugin"]["Id"] == "kwin4_decoration_qml_quickxp_fixture"
    text = (package / "contents" / "ui" / "ThemeMetrics.js").read_text(encoding="utf-8")
    assert '"borderTop": 16' in text
    assert '"borderLeft": 5' in text
    assert "#ABCDEF" in text
    assert "802" not in text
    assert '"width": 4' in text
    assert '"height": 4' in text
