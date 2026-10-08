"""Package a KWin QML decoration from a theme's DWMWindow parts."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[2] / "QuickXP" / "kwin-decoration"


def package_id(slug: str) -> str:
    safe = "".join(ch if ch.isalnum() or ch in "-_" else "_" for ch in slug.strip().lower())
    return f"kwin4_decoration_qml_quickxp_{safe or 'theme'}"


def _frame_size(part: dict) -> tuple[int, int]:
    width = int(part.get("width") or 0)
    height = int(part.get("height") or 0)
    count = max(1, int(part.get("imageCount") or 1))
    if height >= width:
        return width, max(1, height // count) if height else 0
    return max(1, width // count) if width else 0, height


def _part_payload(part: dict, image_name: str) -> dict:
    frame_w, frame_h = _frame_size(part)
    payload = {
        "image": image_name,
        "imageCount": int(part.get("imageCount") or 1),
        "width": int(part.get("width") or 0),
        "height": int(part.get("height") or 0),
        "frameWidth": frame_w,
        "frameHeight": frame_h,
    }
    if part.get("sizingMargins"):
        payload["sizingMargins"] = list(part["sizingMargins"])
    if part.get("contentMargins"):
        payload["contentMargins"] = list(part["contentMargins"])
    return payload


def _metrics(doc: dict, parts: dict[str, dict]) -> dict:
    sizes = doc.get("sizes") if isinstance(doc.get("sizes"), dict) else {}
    colors = doc.get("colors") if isinstance(doc.get("colors"), dict) else {}
    caption = doc.get("caption") if isinstance(doc.get("caption"), dict) else {}
    dwm = doc.get("dwmWindow") if isinstance(doc.get("dwmWindow"), dict) else {}
    sizing = int(sizes.get("sizingBorderWidth") or 0)
    padded = int(sizes.get("paddedBorderWidth") or 0)
    caption_h = int(sizes.get("captionBarHeight") or 0)
    side = sizing + padded
    from .aurorae import glass_plate_alpha

    raw_alpha = colors.get("glassAlpha")
    try:
        color_alpha = int(raw_alpha) if raw_alpha not in (None, "") else None
    except (TypeError, ValueError):
        color_alpha = None
    active_plate = glass_plate_alpha(
        color_alpha, dwm.get("activeOpacity"), dwm.get("activeColorizationOpacity")
    )
    inactive_plate = glass_plate_alpha(
        color_alpha,
        dwm.get("inactiveOpacity", dwm.get("activeOpacity")),
        dwm.get("inactiveColorizationOpacity", dwm.get("activeColorizationOpacity")),
    )
    fonts = doc.get("fonts") if isinstance(doc.get("fonts"), dict) else {}
    return {
        "borderLeft": side,
        "borderRight": side,
        "borderTop": caption_h + side,
        "borderBottom": side,
        "iconSize": 16,
        "plateColor": colors.get("glass") or colors.get("titleActive") or "#000000",
        "activePlateAlpha": (active_plate or 0) / 255,
        "inactivePlateAlpha": (inactive_plate or 0) / 255,
        "titleActiveText": colors.get("titleActiveText") or "#000000",
        "titleInactiveText": colors.get("titleInactiveText") or "#000000",
        "glowColor": caption.get("glowColor") or "#FFFFFF",
        "textGlowSize": int(caption.get("textGlowSize") or 0),
        "fontSize": int(sizes.get("fontSize") or 12),
        "fontFamily": fonts.get("ui") or "Segoe UI",
        "roles": dwm.get("roles") or {},
        "parts": parts,
    }


def _write_metrics(path: Path, metrics: dict) -> None:
    body = json.dumps(metrics, indent=2)
    path.write_text(
        "\n".join(
            [
                ".pragma library",
                f"const metrics = {body}",
                "",
                "function part(id) {",
                "    return metrics.parts[String(id)] || null",
                "}",
                "",
                "function roleId(name) {",
                "    const value = metrics.roles[name]",
                "    return typeof value === \"number\" ? value : 0",
                "}",
                "",
                "function pickGlyph(role, backgroundId) {",
                "    const ids = metrics.roles[role]",
                "    if (!ids || !ids.length)",
                "        return 0",
                "    const bg = part(backgroundId)",
                "    let boxW = bg ? bg.frameWidth : 0",
                "    let boxH = bg ? bg.frameHeight : 0",
                "    if (bg && bg.contentMargins && bg.contentMargins.length === 4) {",
                "        boxW -= bg.contentMargins[0] + bg.contentMargins[1]",
                "        boxH -= bg.contentMargins[2] + bg.contentMargins[3]",
                "    }",
                "    let chosen = ids[0]",
                "    for (let i = 0; i < ids.length; i++) {",
                "        const glyph = part(ids[i])",
                "        if (!glyph)",
                "            continue",
                "        if (glyph.frameWidth <= boxW && glyph.frameHeight <= boxH)",
                "            chosen = ids[i]",
                "    }",
                "    return chosen",
                "}",
                "",
            ]
        ),
        encoding="utf-8",
    )


def _write_mask(path: Path, metrics: dict) -> None:
    del metrics
    # Matches Decoration.cornerRadius in the QML template. Corner tiles are
    # quarter-discs so KWin clips the window to the same curve as the plate.
    radius = 8
    mid = 40
    span = radius * 2 + mid
    far = radius + mid
    path.write_text(
        "\n".join(
            [
                '<?xml version="1.0" encoding="UTF-8"?>',
                f'<svg xmlns="http://www.w3.org/2000/svg" width="{span}" height="{span}">',
                f'  <path id="mask-topleft" d="M{radius},0 A{radius},{radius} 0 0 0 0,{radius} L{radius},{radius} Z" fill="#ffffff"/>',
                f'  <rect id="mask-top" x="{radius}" width="{mid}" height="{radius}" fill="#ffffff"/>',
                f'  <path id="mask-topright" d="M{far},0 A{radius},{radius} 0 0 1 {span},{radius} L{far},{radius} Z" fill="#ffffff"/>',
                f'  <rect id="mask-left" y="{radius}" width="{radius}" height="{mid}" fill="#ffffff"/>',
                f'  <rect id="mask-center" x="{radius}" y="{radius}" width="{mid}" height="{mid}" fill="#ffffff"/>',
                f'  <rect id="mask-right" x="{far}" y="{radius}" width="{radius}" height="{mid}" fill="#ffffff"/>',
                f'  <path id="mask-bottomleft" d="M0,{far} A{radius},{radius} 0 0 0 {radius},{span} L{radius},{far} Z" fill="#ffffff"/>',
                f'  <rect id="mask-bottom" x="{radius}" y="{far}" width="{mid}" height="{radius}" fill="#ffffff"/>',
                f'  <path id="mask-bottomright" d="M{span},{far} A{radius},{radius} 0 0 0 {far},{span} L{far},{far} Z" fill="#ffffff"/>',
                "</svg>",
                "",
            ]
        ),
        encoding="utf-8",
    )


def emit_kdecoration(
    theme_root: str | Path,
    *,
    slug: str | None = None,
    document: dict | None = None,
) -> tuple[dict, list[str], list[str]]:
    """Copy the QML template and theme DWM parts into themes/<slug>/kdecoration/."""
    root = Path(theme_root)
    warnings: list[str] = []
    errors: list[str] = []
    summary: dict = {"ok": False, "path": "", "id": ""}
    doc = document
    if doc is None:
        path = root / "theme.json"
        if not path.is_file():
            errors.append("theme.json missing; cannot emit KWin decoration")
            return summary, warnings, errors
        doc = json.loads(path.read_text(encoding="utf-8"))
    generation = str(doc.get("generation") or "").strip().lower()
    if generation not in ("vista", "win7"):
        summary["skipped"] = True
        return summary, warnings, errors
    dwm = doc.get("dwmWindow") if isinstance(doc.get("dwmWindow"), dict) else {}
    recorded = dwm.get("parts") if isinstance(dwm.get("parts"), dict) else {}
    imaged = {key: part for key, part in recorded.items() if isinstance(part, dict) and part.get("image")}
    if not imaged:
        warnings.append("no DWMWindow atlas parts; QML decoration not emitted")
        summary["skipped"] = True
        return summary, warnings, errors
    if not TEMPLATE.is_dir():
        errors.append(f"decoration template missing: {TEMPLATE}")
        return summary, warnings, errors

    deco_slug = slug or root.name
    deco_id = package_id(deco_slug)
    out_dir = root / "kdecoration"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    shutil.copytree(TEMPLATE, out_dir)
    meta_path = out_dir / "metadata.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta.setdefault("KPlugin", {})["Id"] = deco_id
    meta["KPlugin"]["Name"] = str(doc.get("name") or deco_slug)
    meta_path.write_text(json.dumps(meta, indent=4) + "\n", encoding="utf-8")

    image_dir = out_dir / "contents" / "ui" / "images"
    image_dir.mkdir(parents=True, exist_ok=True)
    packed: dict[str, dict] = {}
    for key, part in imaged.items():
        src = root / str(part["image"])
        if not src.is_file():
            warnings.append(f"DWM part {key} image missing: {part['image']}")
            continue
        dest_name = f"images/{key}.png"
        shutil.copyfile(src, image_dir / f"{key}.png")
        packed[key] = _part_payload(part, dest_name)
    if not packed:
        errors.append("DWMWindow part images could not be copied")
        return summary, warnings, errors

    metrics = _metrics(doc, packed)
    ui = out_dir / "contents" / "ui"
    _write_metrics(ui / "ThemeMetrics.js", metrics)
    _write_mask(ui / "mask.svg", metrics)
    summary.update({"ok": True, "path": str(out_dir), "id": deco_id})
    return summary, warnings, errors
