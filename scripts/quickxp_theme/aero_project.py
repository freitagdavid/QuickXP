"""Project a decoded Aero property store onto theme.json logical keys."""

from __future__ import annotations

import re
from pathlib import Path

from . import aero_binary, aero_vista, class_key_map, extract, project
from .aero_binary import AeroFile, AeroVariant, Prop, lookup

IMAGE_FIELDS = {
    "imagefile": ("IMAGEFILE",),
    "imagefile1": ("IMAGEFILE1", "IMAGEFILE"),
    "imagefile2": ("IMAGEFILE2", "IMAGEFILE1", "IMAGEFILE"),
    "imagefile3": ("IMAGEFILE3", "GLYPHIMAGEFILE"),
    "glyphimagefile": ("GLYPHIMAGEFILE",),
}

SIZING_NAMES = {0: "truesize", 1: "stretch", 2: "tile"}
LAYOUT_NAMES = {0: "vertical", 1: "horizontal"}
OFFSET_NAMES = {
    0: "TopLeft",
    1: "TopRight",
    2: "TopMiddle",
    3: "BottomLeft",
    4: "BottomRight",
    5: "BottomMiddle",
    6: "MiddleLeft",
    7: "MiddleRight",
    8: "LeftOfCaption",
    9: "RightOfCaption",
}

REQUIRED_IMAGES = ("buttonImage", "taskbarImage", "startButtonImage")


def scheme_entries(style: AeroFile) -> list[dict]:
    """One scheme per VARIANT resource. Vista's single NORMAL variant is NormalColor."""
    color_names = [name for name in style.vmap if "color" in name.lower()]
    short_names = [name for name in style.vmap if name.lower() in ("normal", "default")]
    entries: list[dict] = []
    for index, variant in enumerate(style.variants):
        if len(style.variants) == 1 and color_names:
            scheme_id = color_names[0]
            label = short_names[0] if short_names else scheme_id
        else:
            scheme_id = variant.resource_name or f"variant{index}"
            label = scheme_id
        entries.append({"id": scheme_id, "label": label, "variant": variant.resource_name})
    return entries


def project_style(
    style: AeroFile,
    theme_root: str | Path,
    *,
    name: str,
    generation: str = "vista",
    bindings: list[dict] | None = None,
    colorization: str | None = None,
    colorization_alpha: int | None = None,
    active_scheme: str | None = None,
) -> tuple[dict, list[str], list[str]]:
    """Write referenced PNGs under theme_root and return a scheme pack document."""
    root = Path(theme_root)
    root.mkdir(parents=True, exist_ok=True)
    table = aero_vista.BINDINGS if bindings is None else bindings
    warnings: list[str] = []
    errors: list[str] = []
    entries = scheme_entries(style)
    if not entries:
        errors.append("Aero file has no VARIANT property store")
        return {}, warnings, errors

    scheme_data: dict[str, dict] = {}
    listed: list[dict] = []
    for entry in entries:
        variant = style.variant(entry["variant"])
        if variant is None:
            continue
        doc, w, e = _project_variant(
            style,
            variant,
            root,
            name=name,
            generation=generation,
            bindings=table,
            colorization=colorization,
            colorization_alpha=colorization_alpha,
        )
        warnings.extend(w)
        errors.extend(e)
        if not doc.get("images"):
            continue
        scheme_data[entry["id"]] = project.variant_from_doc(doc)
        listed.append({"id": entry["id"], "label": entry["label"]})

    if not scheme_data:
        return {}, warnings, errors or ["no Aero scheme projected"]

    active = active_scheme or ""
    if active not in scheme_data:
        active = listed[0]["id"]
    pack: dict = {
        "name": name,
        "generation": generation,
        "activeScheme": active,
        "schemes": listed,
        "schemeData": scheme_data,
    }
    pack.update(scheme_data[active])
    pack["name"] = name
    pack["generation"] = generation
    return pack, warnings, errors


def _project_variant(
    style: AeroFile,
    variant: AeroVariant,
    root: Path,
    *,
    name: str,
    generation: str,
    bindings: list[dict],
    colorization: str | None,
    colorization_alpha: int | None = None,
) -> tuple[dict, list[str], list[str]]:
    warnings: list[str] = []
    errors: list[str] = []
    images: dict[str, str] = {}
    groups: dict[str, dict] = {}

    for spec in bindings:
        _apply_binding(style, variant, root, spec, images, groups, warnings)

    _apply_start_button(style, variant, root, images, groups, warnings)
    colors = _colors(variant, colorization, colorization_alpha)
    _apply_caption_chrome(variant, groups, colors)
    _apply_dwm_window(style, variant, root, groups, warnings)
    sizes = _sizes(variant, images, root)
    _apply_edit(variant, groups)
    _apply_group_edges(variant, groups)

    groups.setdefault("toolTip", {"fill": "#FFFFE1", "border": "#000000", "text": "#000000"})
    groups.setdefault("messageBox", {"minWidth": 280, "minHeight": 120})
    groups.setdefault("focusRect", {"color": "#000000"})
    if "combo" in groups:
        groups["combo"].setdefault("buttonWidth", 17)
    if "spin" in groups:
        groups["spin"].setdefault("buttonWidth", 15)

    start = groups.setdefault("startButton", {})
    start["composeFlag"] = False
    start.setdefault("text", "")
    start.setdefault("extraWidth", 0)

    for key in REQUIRED_IMAGES:
        if key not in images:
            errors.append(f"required image missing: {key}")

    doc: dict = {
        "name": name,
        "generation": generation,
        "colors": colors,
        "sizes": sizes,
        "images": images,
        "fonts": {"ui": "Segoe UI"},
    }
    for group_name, bag in groups.items():
        if bag:
            doc[group_name] = bag

    project._derive_caption_frames(root, images, groups.get("caption") or {})
    return doc, warnings, errors


def _apply_binding(
    style: AeroFile,
    variant: AeroVariant,
    root: Path,
    spec: dict,
    images: dict[str, str],
    groups: dict[str, dict],
    warnings: list[str],
) -> None:
    classes = spec["classes"]
    part = spec["part"]
    for logical, field in spec.get("images") or []:
        prop = _image_prop(variant, classes, part, field)
        if prop is None:
            if (
                logical not in class_key_map.OPTIONAL_IMAGES
                and logical not in images
                and not logical.endswith("GlyphImage")
            ):
                warnings.append(f"{classes[0]} part {part}: no {field} for {logical}")
            continue
        rel = _write_image(style, root, prop.value)
        if rel is None:
            warnings.append(f"{logical}: image resource {prop.value} missing")
            continue
        images[logical] = rel

    group_name = spec.get("group")
    if not group_name:
        return
    bag = groups.setdefault(group_name, {})
    if spec.get("frames"):
        count = _int_prop(variant, classes, part, "IMAGECOUNT")
        if count is not None:
            bag[spec.get("frames_key", "frames")] = count
    if spec.get("sizing"):
        _put_margins(bag, _margins(variant, classes, part, "SIZINGMARGINS"), spec.get("sizing_prefix", "border"), "edge")
    if spec.get("sizing_prefix") and not spec.get("sizing"):
        _put_margins(bag, _margins(variant, classes, part, "SIZINGMARGINS"), spec["sizing_prefix"], "border")
    if spec.get("content"):
        _put_margins(
            bag,
            _margins(variant, classes, part, "CONTENTMARGINS"),
            spec.get("content_prefix", "content"),
            "edge",
        )
    if spec.get("layout"):
        layout = _enum(variant, classes, part, "IMAGELAYOUT")
        bag["imageLayout"] = LAYOUT_NAMES.get(layout if layout is not None else 0, "vertical")
    if spec.get("sizing_type"):
        sizing = _enum(variant, classes, part, "SIZINGTYPE")
        if sizing is not None:
            bag["sizingType"] = SIZING_NAMES.get(sizing, "stretch")
    if spec.get("text_color"):
        color = _color(variant, classes, part, "TEXTCOLOR")
        if color:
            bag[spec["text_color"]] = color
    if spec.get("fill_hint"):
        hint = _color(variant, classes, part, "FILLCOLORHINT") or _color(variant, classes, part, "FILLCOLOR")
        if hint:
            bag[spec["fill_hint"]] = hint
    if spec.get("offset"):
        pos = lookup(variant, classes, part, "OFFSET")
        if pos is not None and pos.kind == "position":
            x, y = pos.value
            bag["offsetX"] = x
            bag["offsetY"] = y
            bag["offsetTop"] = abs(int(y))
        offset_type = _enum(variant, classes, part, "OFFSETTYPE")
        if offset_type is not None:
            bag["offsetType"] = OFFSET_NAMES.get(offset_type, "TopRight")
    disabled_state = spec.get("disabled_state")
    if disabled_state:
        color = _color(
            variant, classes, part, "TEXTCOLOR", state=disabled_state, inherit_common=False
        )
        if color:
            bag["disabledText"] = color


def _apply_start_button(
    style: AeroFile,
    variant: AeroVariant,
    root: Path,
    images: dict[str, str],
    groups: dict[str, dict],
    warnings: list[str],
) -> None:
    classes = aero_vista.START_BUTTON_CLASSES
    prop = _image_prop(variant, classes, 0, "imagefile1")
    if prop is None:
        warnings.append("start button image missing")
        return
    rel = _write_image(style, root, prop.value)
    if rel is None:
        warnings.append(f"start button image resource {prop.value} missing")
        return
    images["startButtonImage"] = rel
    bag = groups.setdefault("startButton", {})
    count = _int_prop(variant, classes, 0, "IMAGECOUNT")
    if count:
        bag["frames"] = count
    layout = _enum(variant, classes, 0, "IMAGELAYOUT")
    bag["imageLayout"] = LAYOUT_NAMES.get(layout if layout is not None else 0, "vertical")
    sizing = _enum(variant, classes, 0, "SIZINGTYPE")
    bag["sizingType"] = SIZING_NAMES.get(sizing if sizing is not None else 0, "truesize")
    _put_margins(bag, _margins(variant, classes, 0, "SIZINGMARGINS"), "border", "edge")
    _put_margins(bag, _margins(variant, classes, 0, "CONTENTMARGINS"), "content", "edge")
    bag["composeFlag"] = False
    bag["text"] = ""
    bag["extraWidth"] = 0
    bag.setdefault("font", "Segoe UI")


def _apply_caption_chrome(variant: AeroVariant, groups: dict[str, dict], colors: dict[str, str]) -> None:
    """Copy caption metrics from the loaded style. Missing properties stay absent."""
    bag = groups.setdefault("caption", {})
    _put_margins(bag, _margins(variant, ["Window"], 1, "CAPTIONMARGINS"), "captionMargin", "edge")
    shadow = lookup(variant, ["Window"], 0, "TEXTSHADOWOFFSET")
    if shadow is not None and shadow.kind == "position":
        bag["textShadowOffsetX"], bag["textShadowOffsetY"] = shadow.value
    shadow_color = _color(variant, ["Window"], 0, "TEXTSHADOWCOLOR")
    if shadow_color:
        bag["textShadowColor"] = shadow_color
    for name, key in (
        ("ROUNDCORNERWIDTH", "roundCornerWidth"),
        ("ROUNDCORNERHEIGHT", "roundCornerHeight"),
    ):
        value = _int_prop(variant, ["Window"], 1, name)
        if value is None:
            value = _int_prop(variant, ["Window"], 0, name)
        if value is not None:
            bag[key] = value

    composited = ["CompositedWindow::Window"]
    glow_size = _int_prop(variant, composited, 0, "TEXTGLOWSIZE")
    if glow_size is None:
        glow_size = _int_prop(variant, ["globals"], 0, "TEXTGLOWSIZE")
    if glow_size is not None:
        bag["textGlowSize"] = glow_size
    intensity = _int_prop(variant, composited, 0, "GLOWINTENSITY")
    if intensity is None:
        intensity = _int_prop(variant, ["globals"], 0, "GLOWINTENSITY")
    if intensity is not None:
        bag["glowIntensity"] = intensity
    glow = _color(variant, composited, 0, "GLOWCOLOR") or _color(variant, ["globals"], 0, "GLOWCOLOR")
    if glow:
        bag["glowColor"] = glow
    composited_flag = lookup(variant, composited, 0, "COMPOSITED")
    if composited_flag is not None:
        bag["composited"] = bool(composited_flag.value)
    active_text = _color(variant, composited, 1, "TEXTCOLOR", state=1, inherit_common=False)
    inactive_text = _color(variant, composited, 1, "TEXTCOLOR", state=2, inherit_common=False)
    if active_text:
        colors["titleActiveText"] = active_text
    if inactive_text:
        colors["titleInactiveText"] = inactive_text
    if not bag:
        groups.pop("caption", None)


def _apply_dwm_window(
    style: AeroFile,
    variant: AeroVariant,
    root: Path,
    groups: dict[str, dict],
    warnings: list[str],
) -> None:
    """Keep DWMWindow opacities and crop atlas parts into images/dwm/."""
    parts = variant.classes.get("DWMWindow") or {}
    recorded: dict[str, dict] = {}
    plate_part: int | None = None
    plate_rank: tuple[int, int] | None = None
    for part_id, states in parts.items():
        entry_states: dict[str, dict] = {}
        has_active_pair = False
        has_content = False
        for state_id, props in states.items():
            bag: dict = {}
            opacity = props.get("OPACITY")
            if opacity is not None and opacity.kind == "int":
                bag["opacity"] = int(opacity.value)
            color_opacity = props.get("COLORIZATIONOPACITY")
            if color_opacity is not None and color_opacity.kind == "int":
                bag["colorizationOpacity"] = int(color_opacity.value)
            glow = props.get("GLOWCOLOR")
            if glow is not None and glow.kind == "color":
                bag["glowColor"] = str(glow.value)
            if "CONTENTMARGINS" in props and props["CONTENTMARGINS"].kind == "margins":
                has_content = True
                left, right, top, bottom = props["CONTENTMARGINS"].value
                bag["contentLeft"] = left
                bag["contentRight"] = right
                bag["contentTop"] = top
                bag["contentBottom"] = bottom
            if bag:
                entry_states[str(state_id)] = bag
            if state_id == 1 and "opacity" in bag and "colorizationOpacity" in bag:
                has_active_pair = True
        common = states.get(0) or {}
        entry: dict = {}
        if entry_states:
            entry["states"] = entry_states
        count = common.get("IMAGECOUNT")
        if count is not None and count.kind == "int":
            entry["imageCount"] = int(count.value)
        sizing = common.get("SIZINGMARGINS")
        if sizing is not None and sizing.kind == "margins":
            entry["sizingMargins"] = [int(v) for v in sizing.value]
        content = common.get("CONTENTMARGINS")
        if content is not None and content.kind == "margins":
            entry["contentMargins"] = [int(v) for v in content.value]
        rect = common.get("ATLASRECT")
        if rect is not None and rect.kind == "rect":
            entry["rect"] = [int(v) for v in rect.value]
        if not entry:
            continue
        recorded[str(part_id)] = entry
        if has_active_pair:
            rank = (0 if has_content else 1, int(part_id))
            if plate_rank is None or rank < plate_rank:
                plate_rank = rank
                plate_part = int(part_id)
    if not recorded:
        return
    dwm: dict = {"parts": recorded}
    if plate_part is not None:
        states = recorded[str(plate_part)]["states"]
        dwm["platePart"] = plate_part
        active = states.get("1") or states.get("0") or {}
        inactive = states.get("2") or active
        if "opacity" in active:
            dwm["activeOpacity"] = active["opacity"]
        if "colorizationOpacity" in active:
            dwm["activeColorizationOpacity"] = active["colorizationOpacity"]
        if "opacity" in inactive:
            dwm["inactiveOpacity"] = inactive["opacity"]
        if "colorizationOpacity" in inactive:
            dwm["inactiveColorizationOpacity"] = inactive["colorizationOpacity"]
    _crop_dwm_parts(style, variant, root, recorded, warnings)
    roles: dict[str, int | list[int]] = {}
    for role, spec in aero_vista.DWM_ROLES.items():
        ids = spec if isinstance(spec, list) else [spec]
        present = [part for part in ids if "image" in recorded.get(str(part), {})]
        if not present:
            continue
        roles[role] = present if isinstance(spec, list) else present[0]
    if roles:
        dwm["roles"] = roles
    groups["dwmWindow"] = dwm


def _crop_dwm_parts(
    style: AeroFile,
    variant: AeroVariant,
    root: Path,
    recorded: dict[str, dict],
    warnings: list[str],
) -> None:
    atlas_prop = lookup(variant, ["DWMWindow"], 0, "ATLASIMAGE")
    if atlas_prop is None or atlas_prop.kind != "image":
        return
    try:
        atlas_id = int(atlas_prop.value)
    except (TypeError, ValueError):
        return
    blob = style.streams.get(atlas_id) or style.images.get(atlas_id)
    if not blob:
        warnings.append(f"DWMWindow atlas stream {atlas_id} missing")
        return
    try:
        from io import BytesIO

        from PIL import Image

        atlas = Image.open(BytesIO(blob)).convert("RGBA")
    except Exception as exc:
        warnings.append(f"DWMWindow atlas image unreadable: {exc}")
        return
    dest_dir = root / "images" / "dwm"
    dest_dir.mkdir(parents=True, exist_ok=True)
    for part_key, entry in recorded.items():
        rect = entry.get("rect")
        if not rect or len(rect) != 4:
            continue
        left, top, right, bottom = (int(v) for v in rect)
        left = max(0, min(left, atlas.width))
        right = max(left, min(right, atlas.width))
        top = max(0, min(top, atlas.height))
        bottom = max(top, min(bottom, atlas.height))
        if right <= left or bottom <= top:
            continue
        crop = atlas.crop((left, top, right, bottom))
        dest = dest_dir / f"{part_key}.png"
        crop.save(dest, format="PNG")
        entry["image"] = dest.relative_to(root).as_posix()
        entry["width"] = crop.width
        entry["height"] = crop.height


def _colors(
    variant: AeroVariant,
    colorization: str | None,
    colorization_alpha: int | None = None,
) -> dict[str, str]:
    colors: dict[str, str] = {}
    for src, dest in aero_vista.SYS_COLORS.items():
        prop = lookup(variant, ["sysmetrics"], 0, src)
        if prop is not None and prop.kind == "color":
            colors[dest] = str(prop.value)
    btn = colors.get("button")
    if btn:
        colors["window"] = btn
        colors["buttonFace"] = btn
        colors["classicMenu"] = btn
    colors.setdefault("buttonText", "#000000")
    colors.setdefault("taskbarText", "#FFFFFF")
    colors.setdefault("menuText", "#000000")
    colors.setdefault("windowText", "#000000")
    glass = colorization
    glass_alpha = colorization_alpha
    if not glass:
        prop = lookup(variant, ["globals"], 0, "COLORIZATIONCOLOR")
        if prop is not None and prop.kind == "color":
            glass = str(prop.value)
            if glass_alpha is None:
                glass_alpha = prop.alpha
    if glass:
        colors["glass"] = glass
        colors["taskbar"] = glass
        colors["titleActive"] = glass
        if glass_alpha is not None:
            colors["glassAlpha"] = str(int(glass_alpha))
    if colors.get("desktop") in (None, "#000000") and glass:
        colors["desktop"] = glass
    hint = _color(variant, ["TaskBar"], 1, "FILLCOLORHINT")
    if hint and "taskbar" not in colors:
        colors["taskbar"] = hint
    return colors


def _sizes(variant: AeroVariant, images: dict[str, str], root: Path) -> dict[str, int]:
    sizes: dict[str, int] = {"fontSize": 12, "taskbarHeight": 30}
    height = _int_prop(variant, ["sysmetrics"], 0, "CAPTIONBARHEIGHT")
    if height:
        sizes["captionBarHeight"] = height
    for src, dest in (
        ("SIZINGBORDERWIDTH", "sizingBorderWidth"),
        ("CAPTIONBARWIDTH", "captionBarWidth"),
        ("SMCAPTIONBARWIDTH", "smallCaptionBarWidth"),
        ("SMCAPTIONBARHEIGHT", "smallCaptionBarHeight"),
        ("PADDEDBORDERWIDTH", "paddedBorderWidth"),
    ):
        value = _int_prop(variant, ["sysmetrics"], 0, src)
        if value is not None:
            sizes[dest] = value
    width = _int_prop(variant, ["sysmetrics"], 0, "SCROLLBARWIDTH")
    if width:
        sizes["scrollBarWidth"] = width
    rel = images.get("taskbarImage")
    if rel:
        try:
            from PIL import Image

            with Image.open(root / rel) as image:
                if image.size[1] >= 8:
                    sizes["taskbarHeight"] = image.size[1]
        except Exception:
            pass
    return sizes


def _apply_edit(variant: AeroVariant, groups: dict[str, dict]) -> None:
    fill = _color(variant, ["Edit"], 0, "FILLCOLOR")
    border = _color(variant, ["Edit"], 0, "BORDERCOLOR")
    if not fill and not border:
        return
    bag = groups.setdefault("edit", {})
    if fill:
        bag["fill"] = fill
    if border:
        bag["border"] = border
    disabled_fill = _color(variant, ["Edit"], 1, "FILLCOLOR", state=4)
    disabled_text = _color(variant, ["Edit"], 1, "TEXTCOLOR", state=4)
    if disabled_fill:
        bag["disabledFill"] = disabled_fill
    if disabled_text:
        bag["disabledText"] = disabled_text


def _apply_group_edges(variant: AeroVariant, groups: dict[str, dict]) -> None:
    bag = groups.setdefault("groupBox", {})
    for src, dest in aero_vista.EDGE_COLORS:
        prop = lookup(variant, ["globals"], 0, src)
        if prop is not None and prop.kind == "color":
            bag[dest] = str(prop.value)
    if not bag:
        groups.pop("groupBox", None)


def _image_prop(variant: AeroVariant, classes: list[str], part: int, field: str) -> Prop | None:
    for name in IMAGE_FIELDS.get(field, (field.upper(),)):
        found = lookup(variant, classes, part, name)
        if found is not None and found.kind == "image":
            return found
    return None


def _int_prop(variant: AeroVariant, classes: list[str], part: int, name: str, state: int = 0) -> int | None:
    found = lookup(variant, classes, part, name, state)
    if found is None or found.kind not in ("int", "enum"):
        return None
    return int(found.value)


def _enum(variant: AeroVariant, classes: list[str], part: int, name: str) -> int | None:
    found = lookup(variant, classes, part, name)
    if found is None:
        return None
    return int(found.value)


def _color(
    variant: AeroVariant,
    classes: list[str],
    part: int,
    name: str,
    state: int = 0,
    *,
    inherit_common: bool = True,
) -> str | None:
    found = lookup(variant, classes, part, name, state, inherit_common=inherit_common)
    if found is None or found.kind != "color":
        return None
    return str(found.value)


def _margins(variant: AeroVariant, classes: list[str], part: int, name: str):
    found = lookup(variant, classes, part, name)
    if found is None or found.kind != "margins":
        return None
    return found.value


def _put_margins(bag: dict, margins, prefix: str, kind: str) -> None:
    if not margins:
        return
    left, right, top, bottom = margins
    if kind == "border":
        bag[f"{prefix}BorderLeft"] = left
        bag[f"{prefix}BorderRight"] = right
        bag[f"{prefix}BorderTop"] = top
        bag[f"{prefix}BorderBottom"] = bottom
    else:
        bag[f"{prefix}Left"] = left
        bag[f"{prefix}Right"] = right
        bag[f"{prefix}Top"] = top
        bag[f"{prefix}Bottom"] = bottom


def _write_image(style: AeroFile, root: Path, image_id: object) -> str | None:
    try:
        key = int(image_id)
    except (TypeError, ValueError):
        return None
    blob = style.images.get(key)
    if not blob:
        return None
    ext = extract.image_extension(blob) or ".bin"
    dest_dir = root / "images"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / f"{key}{ext}"
    if not dest.is_file() or dest.read_bytes() != blob:
        dest.write_bytes(blob)
    return dest.relative_to(root).as_posix()


def parse_theme_sidecar(path: str | Path) -> dict[str, str]:
    """Read ColorizationColor / ColorStyle from a .theme INI."""
    text = Path(path).read_text(errors="replace")
    found: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.split(";", 1)[0].strip()
        if "=" not in line or line.startswith("["):
            continue
        key, value = line.split("=", 1)
        found[key.strip().lower()] = value.strip()
    result: dict[str, str] = {}
    color = found.get("colorizationcolor", "")
    match = re.fullmatch(r"0x([0-9a-fA-F]{6,8})", color)
    if match:
        digits = match.group(1)
        raw = int(digits, 16)
        result["colorization"] = aero_binary.colorization_to_hex(raw)
        if len(digits) == 8:
            result["colorizationAlpha"] = str(aero_binary.colorization_channels(raw)[1])
    style = found.get("colorstyle")
    if style:
        result["colorStyle"] = style
    return result


def find_theme_sidecar(source: Path) -> Path | None:
    """Locate aero.theme next to an .msstyles (parent, or the file itself)."""
    if source.is_file() and source.suffix.lower() == ".theme":
        return source
    candidates = []
    if source.is_file():
        candidates.append(source.with_suffix(".theme"))
        candidates.append(source.parent / f"{source.stem}.theme")
        candidates.extend(source.parent.glob("*.theme"))
        candidates.extend(source.parent.parent.glob("*.theme"))
    else:
        candidates.extend(source.glob("*.theme"))
    for path in candidates:
        if path.is_file():
            return path
    return None
