"""Emit Plasma Aurorae decoration packages from projected XP caption assets."""

from __future__ import annotations

import base64
import json
import re
import shutil
from pathlib import Path
from xml.sax.saxutils import escape

from . import project as project_mod
from . import schemes as scheme_mod

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    Image = None  # type: ignore


def aurorae_id(slug: str) -> str:
    clean = re.sub(r"[^a-z0-9._-]+", "-", (slug or "theme").strip().lower()).strip(".-")
    return f"quickxp-{clean or 'theme'}"


def hex_to_rgb_csv(value: str | None, fallback: str) -> str:
    text = (value or fallback).strip()
    if text.startswith("#") and len(text) >= 7:
        try:
            r = int(text[1:3], 16)
            g = int(text[3:5], 16)
            b = int(text[5:7], 16)
            return f"{r},{g},{b}"
        except ValueError:
            pass
    return "255,255,255"


def _open_png(theme_root: Path, rel: str | None) -> Image.Image | None:
    if Image is None or not rel:
        return None
    path = theme_root / rel
    if not path.is_file():
        return None
    try:
        return Image.open(path).convert("RGBA")
    except Exception:
        return None


def slice_strip(
    sheet: Image.Image,
    frames: int,
    layout: str = "vertical",
) -> list[Image.Image]:
    frames = max(1, frames)
    width, height = sheet.size
    out: list[Image.Image] = []
    if layout == "horizontal":
        fw = max(1, width // frames)
        for i in range(frames):
            out.append(sheet.crop((i * fw, 0, min(width, (i + 1) * fw), height)))
    else:
        fh = max(1, height // frames)
        for i in range(frames):
            out.append(sheet.crop((0, i * fh, width, min(height, (i + 1) * fh))))
    return out


def nine_slice(image: Image.Image, margins: tuple[int, int, int, int]) -> dict[str, Image.Image]:
    left, right, top, bottom = margins
    width, height = image.size
    left = max(0, min(left, width - 1))
    right = max(0, min(right, width - left - 1))
    top = max(0, min(top, height - 1))
    bottom = max(0, min(bottom, height - top - 1))
    mx0, mx1 = left, width - right
    my0, my1 = top, height - bottom
    return {
        "topleft": image.crop((0, 0, mx0, my0)),
        "top": image.crop((mx0, 0, mx1, my0)),
        "topright": image.crop((mx1, 0, width, my0)),
        "left": image.crop((0, my0, mx0, my1)),
        "center": image.crop((mx0, my0, mx1, my1)),
        "right": image.crop((mx1, my0, width, my1)),
        "bottomleft": image.crop((0, my1, mx0, height)),
        "bottom": image.crop((mx0, my1, mx1, height)),
        "bottomright": image.crop((mx1, my1, width, height)),
    }


def stretch_frame(
    image: Image.Image,
    width: int,
    height: int,
    margins: tuple[int, int, int, int],
) -> Image.Image:
    """Nine-slice enlarge. Aero min/max/help strips are a few pixels wide."""
    width = max(image.width, int(width))
    height = max(image.height, int(height))
    if image.size == (width, height):
        return image
    parts = nine_slice(image, margins)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    left_w = parts["topleft"].width
    right_w = parts["topright"].width
    top_h = parts["topleft"].height
    bottom_h = parts["bottomleft"].height
    mid_w = max(0, width - left_w - right_w)
    mid_h = max(0, height - top_h - bottom_h)

    def paste(part: Image.Image, box: tuple[int, int, int, int]) -> None:
        x0, y0, x1, y1 = box
        if x1 <= x0 or y1 <= y0 or part.width < 1 or part.height < 1:
            return
        scaled = part.resize((x1 - x0, y1 - y0), Image.Resampling.NEAREST)
        out.alpha_composite(scaled, (x0, y0))

    paste(parts["topleft"], (0, 0, left_w, top_h))
    paste(parts["top"], (left_w, 0, left_w + mid_w, top_h))
    paste(parts["topright"], (width - right_w, 0, width, top_h))
    paste(parts["left"], (0, top_h, left_w, top_h + mid_h))
    paste(parts["center"], (left_w, top_h, left_w + mid_w, top_h + mid_h))
    paste(parts["right"], (width - right_w, top_h, width, top_h + mid_h))
    paste(parts["bottomleft"], (0, height - bottom_h, left_w, height))
    paste(parts["bottom"], (left_w, height - bottom_h, left_w + mid_w, height))
    paste(parts["bottomright"], (width - right_w, height - bottom_h, width, height))
    return out


def fit_glyph(glyph: Image.Image, box_w: int, box_h: int) -> Image.Image:
    """Scale a caption glyph down so it stays inside the glass button."""
    if glyph.width <= box_w and glyph.height <= box_h:
        return glyph
    scale = min(box_w / glyph.width, box_h / glyph.height)
    nw = max(1, int(round(glyph.width * scale)))
    nh = max(1, int(round(glyph.height * scale)))
    return glyph.resize((nw, nh), Image.Resampling.LANCZOS)


def _opacity_unit(value: int) -> float:
    """DWM opacity records are percentages. Values above 100 are 0–255."""
    if value <= 0:
        return 0.0
    if value <= 100:
        return value / 100.0
    return min(1.0, value / 255.0)


def glass_plate_alpha(
    color_alpha: int | None,
    opacity: int | None,
    colorization_opacity: int | None,
) -> int | None:
    """Plate alpha from the loaded colorization alpha and DWM opacities.

    Returns None when the theme did not supply any of them.
    """
    if color_alpha is None and opacity is None and colorization_opacity is None:
        return None
    base = 255 if color_alpha is None else max(0, min(255, int(color_alpha)))
    factor = 1.0
    if opacity is not None:
        factor *= _opacity_unit(int(opacity))
    if colorization_opacity is not None:
        factor *= _opacity_unit(int(colorization_opacity))
    return max(0, min(255, int(round(base * factor))))


def composite_button(bg: Image.Image, glyph: Image.Image | None) -> Image.Image:
    out = bg.copy()
    if glyph is None:
        return out
    glyph = fit_glyph(glyph, out.width, out.height)
    gx = max(0, (out.width - glyph.width) // 2)
    gy = max(0, (out.height - glyph.height) // 2)
    out.alpha_composite(glyph, (gx, gy))
    return out


def _png_data_uri(image: Image.Image) -> str:
    from io import BytesIO

    buf = BytesIO()
    image.save(buf, format="PNG")
    encoded = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def _image_group(
    element_id: str,
    image: Image.Image,
    x: int = 0,
    y: int = 0,
) -> str:
    href = _png_data_uri(image)
    return (
        f'  <g id="{escape(element_id)}">\n'
        f'    <image id="{escape(element_id)}-img" x="{x}" y="{y}" '
        f'width="{image.width}" height="{image.height}" '
        f'preserveAspectRatio="none" xlink:href="{href}"/>\n'
        f"  </g>\n"
    )


def write_decoration_svg(
    path: Path,
    active_caption: Image.Image,
    inactive_caption: Image.Image,
    active_left: Image.Image | None,
    active_right: Image.Image | None,
    active_bottom: Image.Image | None,
    inactive_left: Image.Image | None,
    inactive_right: Image.Image | None,
    inactive_bottom: Image.Image | None,
    caption_margins: tuple[int, int, int, int],
) -> None:
    """Build decoration.svg with Aurorae FrameSvg element ids."""
    active = nine_slice(active_caption, caption_margins)
    inactive = nine_slice(inactive_caption, caption_margins)

    # Side/bottom frames: use full strip as the edge tile (no 9-slice needed).
    def edge(img: Image.Image | None, fallback: Image.Image) -> Image.Image:
        return img if img is not None else fallback

    parts: list[str] = [
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="400" height="300">\n',
    ]

    # Active titlebar (top row from caption 9-slice).
    parts.append(_image_group("decoration-topleft", active["topleft"]))
    parts.append(_image_group("decoration-top", active["top"], x=active["topleft"].width))
    parts.append(
        _image_group(
            "decoration-topright",
            active["topright"],
            x=active["topleft"].width + active["top"].width,
        )
    )

    # Sides / bottom — prefer dedicated frame art; fall back to caption sides.
    left = edge(active_left, active["left"])
    right = edge(active_right, active["right"])
    bottom = edge(active_bottom, active["bottom"])
    parts.append(_image_group("decoration-left", left))
    parts.append(_image_group("decoration-right", right))
    parts.append(_image_group("decoration-bottom", bottom))
    parts.append(_image_group("decoration-bottomleft", active["bottomleft"]))
    parts.append(_image_group("decoration-bottomright", active["bottomright"]))
    # Center fill (client area mask) — solid from caption center sample.
    center = active["center"]
    if center.width < 1 or center.height < 1:
        center = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    parts.append(_image_group("decoration-center", center))

    parts.append(_image_group("decoration-inactive-topleft", inactive["topleft"]))
    parts.append(
        _image_group("decoration-inactive-top", inactive["top"], x=inactive["topleft"].width)
    )
    parts.append(
        _image_group(
            "decoration-inactive-topright",
            inactive["topright"],
            x=inactive["topleft"].width + inactive["top"].width,
        )
    )
    ileft = edge(inactive_left, inactive["left"])
    iright = edge(inactive_right, inactive["right"])
    ibottom = edge(inactive_bottom, inactive["bottom"])
    parts.append(_image_group("decoration-inactive-left", ileft))
    parts.append(_image_group("decoration-inactive-right", iright))
    parts.append(_image_group("decoration-inactive-bottom", ibottom))
    parts.append(_image_group("decoration-inactive-bottomleft", inactive["bottomleft"]))
    parts.append(_image_group("decoration-inactive-bottomright", inactive["bottomright"]))
    icenter = inactive["center"]
    if icenter.width < 1 or icenter.height < 1:
        icenter = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    parts.append(_image_group("decoration-inactive-center", icenter))

    parts.append("</svg>\n")
    path.write_text("".join(parts), encoding="utf-8")


BUTTON_STATE_MAP = (
    ("active-center", 0),
    ("hover-center", 1),
    ("pressed-center", 2),
    ("deactivated-center", 3),
    ("inactive-center", 4),
    ("inactive-hover-center", 5),
    ("inactive-pressed-center", 6),
)


def write_button_svg(
    path: Path,
    backgrounds: list[Image.Image],
    glyphs: list[Image.Image] | None,
) -> None:
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>\n',
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{max(1, backgrounds[0].width)}" '
        f'height="{max(1, backgrounds[0].height * 4)}">\n',
    ]
    y = 0
    for element_id, index in BUTTON_STATE_MAP:
        bg = backgrounds[min(index, len(backgrounds) - 1)]
        glyph = None
        if glyphs:
            glyph = glyphs[min(index, len(glyphs) - 1)]
        composed = composite_button(bg, glyph)
        parts.append(_image_group(element_id, composed, y=y))
        y += composed.height
    parts.append("</svg>\n")
    path.write_text("".join(parts), encoding="utf-8")


def write_metadata_desktop(path: Path, deco_id: str, display_name: str) -> None:
    path.write_text(
        "\n".join(
            [
                "[Desktop Entry]",
                f"Name={display_name}",
                "Comment=QuickXP theme window decoration",
                "X-KDE-PluginInfo-Author=QuickXP",
                f"X-KDE-PluginInfo-Name={deco_id}",
                "X-KDE-PluginInfo-Version=1.0",
                "X-KDE-PluginInfo-Category=Aurorae Theme",
                "X-KDE-PluginInfo-Depends=",
                "X-KDE-PluginInfo-License=GPL",
                "X-KDE-PluginInfo-EnabledByDefault=true",
                "",
            ]
        ),
        encoding="utf-8",
    )


def write_rc(
    path: Path,
    *,
    colors: dict,
    caption: dict,
    caption_height: int,
    button_size: tuple[int, int],
    border_left: int,
    border_right: int,
    border_bottom: int,
    button_margin_top: int | None = None,
    menu_width: int | None = None,
    center_buttons: bool = False,
) -> None:
    # SizingMargins are nine-slice seams inside the caption bitmap, not the
    # title inset. Outer inset is CAPTIONMARGINS. The icon box and the title's
    # top inset are the caption sizing template's CONTENTMARGINS.
    title_h = max(16, int(caption_height))
    bw, bh = button_size
    bw = max(12, int(bw))
    bh = max(12, int(bh))
    if center_buttons:
        if bh > title_h:
            title_h = bh
        margin = max(0, (title_h - bh) // 2)
    elif button_margin_top is None:
        margin = max(0, (title_h - bh) // 2)
    else:
        margin = max(0, int(button_margin_top))
        if margin + bh >= title_h:
            title_h = margin + bh + max(1, min(margin, 4))
    active = hex_to_rgb_csv(colors.get("titleActiveText"), "#FFFFFF")
    inactive = hex_to_rgb_csv(colors.get("titleInactiveText"), "#D8E4F8")
    edge_left = int(caption["captionMarginLeft"]) if "captionMarginLeft" in caption else 4
    edge_right = int(caption["captionMarginRight"]) if "captionMarginRight" in caption else 4
    edge_top = int(caption["captionMarginTop"]) if "captionMarginTop" in caption else 0
    if center_buttons:
        # Buttons are anchored to the outer window edge. Clear the side frame
        # so they sit on the caption instead of in the corner.
        edge_left = max(edge_left, int(border_left))
        edge_right = max(edge_right, int(border_right))
    if "templateContentLeft" in caption:
        box = int(caption.get("templateContentLeft") or 0)
        menu = int(menu_width) if menu_width is not None else box
        title_border_left = max(0, box - menu)
        title_border_right = max(0, int(caption.get("templateContentRight") or 0))
    elif "contentLeft" in caption or "contentRight" in caption:
        title_border_left = max(0, int(caption.get("contentLeft") or 0))
        title_border_right = max(0, int(caption.get("contentRight") or 0))
    else:
        title_border_left = 0
        title_border_right = 0
    lines = [
        "[General]",
        f"ActiveTextColor={active}",
        f"InactiveTextColor={inactive}",
        "TitleAlignment=Left",
        "TitleVerticalAlignment=Center",
        "Animation=0",
    ]
    glow_color = caption.get("glowColor")
    glow_size = caption.get("textGlowSize")
    if glow_color or glow_size is not None:
        lines.append("UseTextShadow=true")
        lines.append("HaloActive=true")
        lines.append("HaloInactive=true")
        if glow_color:
            glow_csv = hex_to_rgb_csv(str(glow_color), "#FFFFFF")
            lines.append(f"ActiveTextShadowColor={glow_csv}")
            lines.append(f"InactiveTextShadowColor={glow_csv}")
        offset_x = int(caption.get("textShadowOffsetX") or 0)
        offset_y = int(caption.get("textShadowOffsetY") or 0)
        lines.append(f"TextShadowOffsetX={offset_x}")
        lines.append(f"TextShadowOffsetY={offset_y}")
        if glow_size is not None:
            lines.append(f"TextGlowSize={int(glow_size)}")
    lines.extend(
        [
            "",
            "[Layout]",
            f"BorderLeft={max(1, border_left)}",
            f"BorderRight={max(1, border_right)}",
            f"BorderBottom={max(1, border_bottom)}",
            f"TitleEdgeTop={max(0, edge_top)}",
            "TitleEdgeBottom=0",
            f"TitleEdgeLeft={max(0, edge_left)}",
            f"TitleEdgeRight={max(0, edge_right)}",
            "TitleEdgeTopMaximized=0",
            "TitleEdgeBottomMaximized=0",
            "TitleEdgeLeftMaximized=0",
            "TitleEdgeRightMaximized=0",
            f"TitleBorderLeft={title_border_left}",
            f"TitleBorderRight={title_border_right}",
            f"TitleHeight={title_h}",
            f"ButtonWidth={bw}",
            f"ButtonHeight={bh}",
        ]
    )
    if menu_width is not None:
        lines.append(f"ButtonWidthMenu={max(1, int(menu_width))}")
    lines.extend(
        [
            "ButtonSpacing=0",
            f"ButtonMarginTop={margin}",
            f"ButtonMarginTopMaximized={margin}",
            "ExplicitButtonSpacer=0",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def emit_aurorae(
    theme_root: str | Path,
    *,
    slug: str | None = None,
    document: dict | None = None,
) -> tuple[dict, list[str], list[str]]:
    """Write themes/<slug>/aurorae/ package. Returns (summary, warnings, errors)."""
    root = Path(theme_root).resolve()
    warnings: list[str] = []
    errors: list[str] = []
    summary: dict = {"ok": False, "path": None, "id": None}

    if Image is None:
        errors.append("Pillow is required to emit Aurorae packages")
        return summary, warnings, errors

    doc = document
    if doc is None:
        theme_json = root / "theme.json"
        if not theme_json.is_file():
            errors.append(f"theme.json missing at {theme_json}")
            return summary, warnings, errors
        try:
            doc = json.loads(theme_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"invalid theme.json: {exc}")
            return summary, warnings, errors

    assert doc is not None
    images = doc.get("images") if isinstance(doc.get("images"), dict) else {}
    colors = doc.get("colors") if isinstance(doc.get("colors"), dict) else {}
    sizes = doc.get("sizes") if isinstance(doc.get("sizes"), dict) else {}
    caption = doc.get("caption") if isinstance(doc.get("caption"), dict) else {}
    frame = doc.get("frame") if isinstance(doc.get("frame"), dict) else {}

    active = _open_png(root, images.get("captionActiveImage") or images.get("captionImage"))
    inactive = _open_png(root, images.get("captionInactiveImage") or images.get("captionImage"))
    if active is None:
        errors.append("caption image missing; cannot emit Aurorae decoration")
        return summary, warnings, errors
    if inactive is None:
        inactive = active.copy()

    left_frames: list = []
    right_frames: list = []
    bottom_frames: list = []
    if images.get("frameLeftImage"):
        img = _open_png(root, images["frameLeftImage"])
        left_frames = slice_strip(img, int(frame.get("leftFrames") or 2), "vertical") if img else []
    else:
        warnings.append("frameLeftImage missing; using caption sides")
    if images.get("frameRightImage"):
        img = _open_png(root, images["frameRightImage"])
        right_frames = slice_strip(img, int(frame.get("rightFrames") or 2), "vertical") if img else []
    else:
        warnings.append("frameRightImage missing; using caption sides")
    if images.get("frameBottomImage"):
        img = _open_png(root, images["frameBottomImage"])
        bottom_frames = (
            slice_strip(img, int(frame.get("bottomFrames") or 2), "vertical") if img else []
        )
    else:
        warnings.append("frameBottomImage missing; using caption bottom")

    deco_slug = slug or root.name
    deco_id = aurorae_id(deco_slug)
    out_dir = root / "aurorae"
    if out_dir.exists():
        shutil.rmtree(out_dir)
    out_dir.mkdir(parents=True)

    margins = (
        int(caption.get("borderLeft") or 8),
        int(caption.get("borderRight") or 8),
        int(caption.get("borderTop") or 4),
        int(caption.get("borderBottom") or 4),
    )
    write_decoration_svg(
        out_dir / "decoration.svg",
        active,
        inactive,
        left_frames[0] if left_frames else None,
        right_frames[0] if right_frames else None,
        bottom_frames[0] if bottom_frames else None,
        left_frames[1] if len(left_frames) > 1 else (left_frames[0] if left_frames else None),
        right_frames[1] if len(right_frames) > 1 else (right_frames[0] if right_frames else None),
        bottom_frames[1]
        if len(bottom_frames) > 1
        else (bottom_frames[0] if bottom_frames else None),
        margins,
    )

    button_jobs = [
        ("close", "closeButtonImage", "closeGlyphImage", "close.svg"),
        ("minimize", "minButtonImage", "minGlyphImage", "minimize.svg"),
        ("maximize", "maxButtonImage", "maxGlyphImage", "maximize.svg"),
        ("restore", "restoreButtonImage", "restoreGlyphImage", "restore.svg"),
        ("help", "helpButtonImage", "helpGlyphImage", "help.svg"),
    ]
    button_w = button_h = 21
    caption_button = doc.get("captionButton") if isinstance(doc.get("captionButton"), dict) else {}
    layout = str(caption_button.get("imageLayout") or "vertical").lower()
    frames = int(caption_button.get("frames") or 8)
    button_margins = (
        int(caption_button.get("borderLeft") or 0),
        int(caption_button.get("borderRight") or 0),
        int(caption_button.get("borderTop") or 0),
        int(caption_button.get("borderBottom") or 0),
    )

    prepared: list[tuple[str, list, list | None]] = []
    for _name, bg_key, glyph_key, filename in button_jobs:
        bg_img = _open_png(root, images.get(bg_key))
        if bg_img is None:
            if filename == "help.svg":
                continue
            warnings.append(f"{bg_key} missing; skipped {filename}")
            continue
        bgs = slice_strip(bg_img, frames, layout)
        glyph_img = _open_png(root, images.get(glyph_key))
        glyphs = slice_strip(glyph_img, frames, layout) if glyph_img is not None else None
        prepared.append((filename, bgs, glyphs))

    if prepared:
        button_w = max(part.width for _filename, bgs, _glyphs in prepared for part in bgs)
        button_h = max(part.height for _filename, bgs, _glyphs in prepared for part in bgs)
        for filename, bgs, glyphs in prepared:
            fitted = [
                stretch_frame(part, button_w, button_h, button_margins) for part in bgs
            ]
            write_button_svg(out_dir / filename, fitted, glyphs)

    # Prefer the active caption frame height so the bitmap isn't squashed; never
    # go below SysMetrics CaptionBarHeight when present.
    metric_h = int(sizes.get("captionBarHeight") or 0)
    frame_h = int(active.height) if active is not None else 0
    caption_height = max(metric_h, frame_h, 16)
    caption_button = doc.get("captionButton") if isinstance(doc.get("captionButton"), dict) else {}
    offset_top = caption_button.get("offsetTop")
    if offset_top is None:
        offset_top = caption_button.get("offsetY")
    if offset_top is not None:
        button_margin_top = abs(int(offset_top))
    elif "templateContentTop" in caption:
        button_margin_top = int(caption.get("templateContentTop") or 0)
    else:
        button_margin_top = None
    menu_width = int(caption["templateContentLeft"]) if "templateContentLeft" in caption else None

    border_left = int(frame.get("leftBorderLeft") or frame.get("leftBorderRight") or 4)
    if left_frames:
        border_left = max(border_left, left_frames[0].width)
    border_right = int(frame.get("rightBorderLeft") or frame.get("rightBorderRight") or 4)
    if right_frames:
        border_right = max(border_right, right_frames[0].width)
    border_bottom = int(frame.get("bottomBorderTop") or frame.get("bottomBorderBottom") or 4)
    if bottom_frames:
        border_bottom = max(border_bottom, bottom_frames[0].height)

    write_rc(
        out_dir / f"{deco_id}rc",
        colors=colors,
        caption=caption,
        caption_height=caption_height,
        button_size=(button_w, button_h),
        border_left=border_left,
        border_right=border_right,
        border_bottom=border_bottom,
        button_margin_top=button_margin_top,
        menu_width=menu_width,
    )
    write_metadata_desktop(
        out_dir / "metadata.desktop",
        deco_id,
        str(doc.get("name") or deco_slug),
    )

    summary.update(
        {
            "ok": True,
            "path": str(out_dir),
            "id": deco_id,
            "files": sorted(p.name for p in out_dir.iterdir() if p.is_file()),
        }
    )
    return summary, warnings, errors


def generate_for_theme_root(
    theme_root: str | Path,
    *,
    slug: str | None = None,
    ini: str | None = None,
) -> dict:
    """Project (if needed) + emit Aurorae; returns JSON-serializable result."""
    root = Path(theme_root).resolve()
    result: dict = {
        "ok": False,
        "path": str(root),
        "warnings": [],
        "errors": [],
        "aurorae": None,
    }
    theme_json = root / "theme.json"
    doc: dict | None = None
    if theme_json.is_file():
        try:
            doc = json.loads(theme_json.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            doc = None

    # Ensure caption fields exist — reproject active scheme when missing.
    if not doc or not (doc.get("images") or {}).get("captionImage"):
        ini_path = scheme_mod.resolve_scheme(root, ini)
        if ini_path is None:
            result["errors"].append("no scheme INI found to project caption assets")
            return result
        doc, warnings, errors = project_mod.project_theme_pack(
            root,
            name=(doc or {}).get("name"),
            generation=(doc or {}).get("generation") or "xp",
            slug=slug or root.name,
            ini=ini_path.name,
        )
        result["warnings"].extend(warnings)
        result["errors"].extend(errors)
        if not doc:
            return result
        doc = project_mod.ensure_start_flag(root, doc)
        # Preserve prior source metadata.
        if theme_json.is_file():
            try:
                prev = json.loads(theme_json.read_text(encoding="utf-8"))
                for key in ("sourceHash", "sourceFile"):
                    if prev.get(key) and key not in doc:
                        doc[key] = prev[key]
            except json.JSONDecodeError:
                pass
        project_mod.write_theme_json(root, doc)

    summary, warnings, errors = emit_aurorae(root, slug=slug or root.name, document=doc)
    result["warnings"].extend(warnings)
    result["errors"].extend(errors)
    result["aurorae"] = summary
    from . import kdecoration

    kdeco_summary, kdeco_warnings, kdeco_errors = kdecoration.emit_kdecoration(
        root,
        slug=slug or root.name,
        document=doc,
    )
    result["warnings"].extend(kdeco_warnings)
    result["errors"].extend(kdeco_errors)
    result["kdecoration"] = kdeco_summary
    result["ok"] = bool(summary.get("ok"))
    return result
