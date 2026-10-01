"""Project XP TEXTFILE INI + converted PNGs into QuickXP theme.json."""

from __future__ import annotations

import json
import re
from pathlib import Path

from . import class_key_map as keymap
from .convert import parse_color, resource_name


def parse_ini(path: Path) -> dict[str, dict[str, str]]:
    """Parse an XP theme INI into {section_lower: {key_lower: value}}."""
    sections: dict[str, dict[str, str]] = {}
    current: str | None = None
    for raw in path.read_text(errors="replace").splitlines():
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip().lower()
            sections.setdefault(current, {})
            continue
        if current is None or "=" not in line:
            continue
        key, value = line.split("=", 1)
        sections[current][key.strip().lower()] = value.strip()
    return sections


def parse_margins(value: str | None) -> tuple[int, int, int, int] | None:
    if not value:
        return None
    parts = re.split(r"[,\s]+", value.strip())
    if len(parts) < 4:
        return None
    try:
        left, right, top, bottom = (int(parts[i]) for i in range(4))
    except ValueError:
        return None
    return left, right, top, bottom


def parse_int(value: str | None) -> int | None:
    if value is None:
        return None
    try:
        return int(value.strip().split()[0])
    except (ValueError, IndexError):
        return None


def rgb_to_hex(rgb: tuple[int, int, int] | None) -> str | None:
    if rgb is None:
        return None
    return "#{:02X}{:02X}{:02X}".format(*rgb)


def pick_image_field(section: dict[str, str], field: str) -> str | None:
    """Prefer ImageFile1 (96 DPI) when asking for imagefile1; else ImageFile."""
    if field == "imagefile1":
        for key in ("imagefile1", "imagefile"):
            if section.get(key):
                return section[key]
        return None
    if field == "imagefile2":
        for key in ("imagefile2", "imagefile1", "imagefile"):
            if section.get(key):
                return section[key]
        return None
    if field == "imagefile3":
        for key in ("imagefile3", "glyphimagefile", "imagefile2", "imagefile1"):
            if section.get(key):
                return section[key]
        return None
    if field == "stockimagefile":
        return section.get("stockimagefile") or section.get("imagefile1") or section.get(
            "imagefile"
        )
    return section.get(field)


def find_png(theme_root: Path, image_file: str) -> Path | None:
    stem = resource_name(image_file)
    # Exact stem match under theme root.
    matches = sorted(theme_root.rglob(f"{stem}.png")) + sorted(
        theme_root.rglob(f"{stem}.PNG")
    )
    if matches:
        return matches[0]
    # Fall back to BMP sibling still awaiting convert.
    bmps = sorted(theme_root.rglob(f"{stem}.bmp")) + sorted(
        theme_root.rglob(f"{stem}.BMP")
    )
    if bmps:
        return bmps[0].with_suffix(".png")
    return None


def relative_image(theme_root: Path, absolute: Path) -> str:
    try:
        return absolute.resolve().relative_to(theme_root.resolve()).as_posix()
    except ValueError:
        return absolute.name


def _derive_caption_frames(
    theme_root: Path,
    images: dict[str, str],
    caption: dict,
) -> None:
    """Slice Window.Caption strip into captionActiveImage / captionInactiveImage."""
    rel = images.get("captionImage")
    if not rel:
        return
    src = theme_root / rel
    if not src.is_file():
        return
    try:
        from PIL import Image
    except Exception:
        return
    try:
        sheet = Image.open(src).convert("RGBA")
    except Exception:
        return
    frames = int(caption.get("frames") or 2)
    layout = str(caption.get("imageLayout") or "vertical").lower()
    if frames < 1:
        frames = 1
    width, height = sheet.size
    out_dir = theme_root / "images" / "caption_frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = src.stem

    def save_frame(index: int, name: str) -> None:
        if layout == "horizontal":
            fw = max(1, width // frames)
            box = (index * fw, 0, min(width, (index + 1) * fw), height)
        else:
            fh = max(1, height // frames)
            box = (0, index * fh, width, min(height, (index + 1) * fh))
        dest = out_dir / f"{stem}-{name}.png"
        sheet.crop(box).save(dest)
        images[f"caption{name.capitalize()}Image"] = relative_image(theme_root, dest)

    save_frame(0, "active")
    if frames > 1:
        save_frame(1, "inactive")
    else:
        images["captionInactiveImage"] = images.get("captionActiveImage", rel)


def infer_image_layout(
    section: dict[str, str],
    png_path: Path | None,
    frames: int,
) -> str:
    """Return 'horizontal' or 'vertical' for multi-frame bitmaps."""
    raw = (section.get("imagelayout") or "").strip().lower()
    if raw in ("horizontal", "vertical"):
        return raw
    if frames <= 1 or png_path is None or not png_path.is_file():
        return "vertical"
    try:
        from PIL import Image

        width, height = Image.open(png_path).size
    except Exception:
        return "vertical"
    if width % frames == 0 and height % frames != 0:
        return "horizontal"
    if height % frames == 0 and width % frames != 0:
        return "vertical"
    if width % frames == 0 and height % frames == 0:
        # Prefer the orientation that yields a wider-than-tall frame (Start buttons).
        if (width // frames) >= height:
            return "horizontal"
        return "vertical"
    return "vertical"


def average_image_hex(png_path: Path) -> str | None:
    """Rough fill color from a PNG (for themes missing FillColorHint)."""
    try:
        from PIL import Image
    except Exception:
        return None
    try:
        image = Image.open(png_path).convert("RGBA")
    except Exception:
        return None
    width, height = image.size
    if width < 1 or height < 1:
        return None
    # Sample a center band; skip fully transparent / magenta key pixels.
    total = [0, 0, 0]
    count = 0
    for y in range(height // 4, max(height // 4 + 1, (3 * height) // 4)):
        for x in range(width):
            r, g, b, a = image.getpixel((x, y))
            if a < 16:
                continue
            if r > 250 and g < 5 and b > 250:
                continue
            total[0] += r
            total[1] += g
            total[2] += b
            count += 1
    if count == 0:
        return None
    return "#{:02X}{:02X}{:02X}".format(
        total[0] // count,
        total[1] // count,
        total[2] // count,
    )


def _section_get(sections: dict, name: str) -> dict[str, str]:
    return sections.get(name.lower(), {})


def project_theme(
    theme_root: str | Path,
    ini_path: str | Path,
    *,
    name: str | None = None,
    generation: str = "xp",
    slug: str | None = None,
) -> tuple[dict, list[str], list[str]]:
    """Build theme.json dict from INI + assets.

    Returns (document, warnings, errors).
    """
    root = Path(theme_root).resolve()
    ini = Path(ini_path).resolve()
    warnings: list[str] = []
    errors: list[str] = []

    if not ini.is_file():
        errors.append(f"INI not found: {ini}")
        return {}, warnings, errors

    sections = parse_ini(ini)
    images: dict[str, str] = {}
    groups: dict[str, dict] = {}

    for section_name, bindings in keymap.IMAGE_BINDINGS.items():
        section = _section_get(sections, section_name)
        if not section:
            for logical, _field in bindings:
                if logical not in keymap.OPTIONAL_IMAGES:
                    warnings.append(f"missing section [{section_name}] for {logical}")
            continue
        for logical, field in bindings:
            raw = pick_image_field(section, field)
            if not raw:
                warnings.append(f"{section_name}: no {field} for {logical}")
                continue
            png = find_png(root, raw)
            if png is None or not png.exists():
                warnings.append(
                    f"{logical}: asset not found for {raw} ({resource_name(raw)})"
                )
                continue
            images[logical] = relative_image(root, png)

    # Colors from SysMetrics + globals + button border hint
    colors: dict[str, str] = {}
    sysm = _section_get(sections, "SysMetrics")
    for src, dest in keymap.COLOR_MAP.items():
        hex_color = rgb_to_hex(parse_color(sysm.get(src)))
        if hex_color:
            colors[dest] = hex_color

    # XP dialog face is Btnface, not Window (often pure white)
    btnface = rgb_to_hex(parse_color(sysm.get("btnface")))
    if btnface:
        colors["window"] = btnface
        colors["button"] = btnface
    elif "window" not in colors:
        colors["window"] = keymap.WINDOW_FACE_FALLBACK

    colors.setdefault("buttonText", keymap.BUTTON_TEXT_DEFAULT)
    colors.setdefault("taskbarText", keymap.TASKBAR_TEXT_DEFAULT)
    colors.setdefault("menuText", keymap.MENU_TEXT_DEFAULT)
    colors.setdefault("windowText", keymap.BUTTON_TEXT_DEFAULT)

    taskbar = _section_get(sections, "TaskBar.BackgroundBottom")
    fill = rgb_to_hex(parse_color(taskbar.get("fillcolorhint")))
    if fill:
        colors["taskbar"] = fill
    elif images.get("taskbarImage"):
        sampled = average_image_hex(root / images["taskbarImage"])
        if sampled:
            colors["taskbar"] = sampled

    push = _section_get(sections, "button.pushbutton")
    border = rgb_to_hex(parse_color(push.get("bordercolorhint")))
    if border:
        colors["border"] = border

    globals_sec = _section_get(sections, "globals")

    sizes: dict[str, int] = {"fontSize": 11}
    scroll_w = parse_int(sysm.get("scrollbarwidth"))
    if scroll_w:
        sizes["taskbarHeight"] = 30  # shell default; real height from taskbar art
    caption_h = parse_int(sysm.get("captionbarheight"))
    if caption_h:
        sizes["captionBarHeight"] = caption_h

    # Group projections
    for spec in keymap.GROUP_BINDINGS:
        section = _section_get(sections, spec["section"])
        group_name = spec["group"]
        bag = groups.setdefault(group_name, {})

        frames_field = spec.get("frames")
        if frames_field and section:
            count = parse_int(section.get(frames_field))
            if count is not None:
                bag[spec.get("frames_key", "frames")] = count

        if spec.get("sizing") and section:
            margins = parse_margins(section.get("sizingmargins"))
            if margins:
                left, right, top, bottom = margins
                prefix = spec.get("sizing_prefix", "border")
                bag[f"{prefix}Left"] = left
                bag[f"{prefix}Right"] = right
                bag[f"{prefix}Top"] = top
                bag[f"{prefix}Bottom"] = bottom

        if spec.get("sizing_prefix") and section and not spec.get("sizing"):
            margins = parse_margins(section.get("sizingmargins"))
            if margins:
                left, right, top, bottom = margins
                prefix = spec["sizing_prefix"]
                bag[f"{prefix}BorderLeft"] = left
                bag[f"{prefix}BorderRight"] = right
                bag[f"{prefix}BorderTop"] = top
                bag[f"{prefix}BorderBottom"] = bottom

        if spec.get("content") and section:
            margins = parse_margins(section.get("contentmargins"))
            if margins:
                left, right, top, bottom = margins
                bag["contentLeft"] = left
                bag["contentRight"] = right
                bag["contentTop"] = top
                bag["contentBottom"] = bottom

        if spec.get("image_layout") and section:
            frames = parse_int(section.get("imagecount")) or bag.get("frames") or 1
            image_file = pick_image_field(section, "imagefile")
            png = find_png(root, image_file) if image_file else None
            bag["imageLayout"] = infer_image_layout(section, png, int(frames))

        if spec.get("sizing_type") and section:
            sizing = (section.get("sizingtype") or "").strip()
            if sizing:
                bag["sizingType"] = sizing.lower().replace(" ", "")

        if spec.get("font") and section:
            font = section.get("font")
            if font:
                # "Franklin Gothic Medium, 14, italic"
                parts = [p.strip() for p in font.split(",")]
                if parts:
                    bag["font"] = parts[0]
                if len(parts) > 1:
                    size = parse_int(parts[1])
                    if size is not None:
                        bag["fontSize"] = size
                style_bits = ",".join(parts[2:]).lower() if len(parts) > 2 else ""
                bag["italic"] = "italic" in style_bits
                bag["bold"] = "bold" in style_bits
            bag.setdefault("text", "start")
            bag.setdefault("extraWidth", 10)

        if spec.get("text_color") and section:
            hex_color = rgb_to_hex(parse_color(section.get("textcolor")))
            if hex_color:
                bag["textColor"] = hex_color

        if spec.get("shadow") and section:
            hex_color = rgb_to_hex(parse_color(section.get("textshadowcolor")))
            if hex_color:
                bag["shadowColor"] = hex_color
            offset = section.get("textshadowoffset")
            if offset:
                parts = re.split(r"[,\s]+", offset.strip())
                if len(parts) >= 2:
                    try:
                        bag["shadowOffsetX"] = int(parts[0])
                        bag["shadowOffsetY"] = int(parts[1])
                    except ValueError:
                        pass

        if spec.get("offset") and section:
            offset = section.get("offset")
            if offset:
                parts = re.split(r"[,\s]+", offset.strip())
                if len(parts) >= 2:
                    try:
                        bag["offsetX"] = int(parts[0])
                        bag["offsetY"] = int(parts[1])
                        # Vertical component is top padding inside the caption bar.
                        bag["offsetTop"] = abs(int(parts[1]))
                    except ValueError:
                        pass
            offset_type = (section.get("offsettype") or "").strip()
            if offset_type:
                bag["offsetType"] = offset_type

        if spec.get("disabled_text_section"):
            disabled = _section_get(sections, spec["disabled_text_section"])
            hex_color = rgb_to_hex(parse_color(disabled.get("textcolor")))
            if hex_color:
                bag["disabledText"] = hex_color

        if spec.get("fill_hint_key"):
            hint_sec = _section_get(sections, spec.get("fill_hint_section", spec["section"]))
            hex_color = rgb_to_hex(parse_color(hint_sec.get("fillcolorhint")))
            if hex_color:
                bag[spec["fill_hint_key"]] = hex_color

        if spec.get("width_from_sysmetrics") and scroll_w:
            bag["width"] = scroll_w

        if spec.get("globals_edges") and globals_sec:
            mapping = (
                ("edgeshadowcolor", "edgeShadow"),
                ("edgehighlightcolor", "edgeHighlight"),
                ("edgelightcolor", "edgeLight"),
                ("edgedkshadowcolor", "edgeDkShadow"),
            )
            for src, dest in mapping:
                hex_color = rgb_to_hex(parse_color(globals_sec.get(src)))
                if hex_color:
                    bag[dest] = hex_color

    # Edit colors from [edit]
    edit = _section_get(sections, "edit")
    if edit:
        edit_bag = groups.setdefault("edit", {})
        fill = rgb_to_hex(parse_color(edit.get("fillcolor")))
        border_c = rgb_to_hex(parse_color(edit.get("bordercolor")))
        if fill:
            edit_bag["fill"] = fill
        if border_c:
            edit_bag["border"] = border_c
        disabled = _section_get(sections, "edit.edittext(Disabled)")
        if disabled:
            dfill = rgb_to_hex(parse_color(disabled.get("fillcolor")))
            if dfill:
                edit_bag["disabledFill"] = dfill
            dtext = rgb_to_hex(parse_color(disabled.get("textcolor")))
            if dtext:
                edit_bag["disabledText"] = dtext
        readonly = _section_get(sections, "edit.edittext(ReadOnly)")
        if readonly:
            rfill = rgb_to_hex(parse_color(readonly.get("fillcolor")))
            if rfill:
                edit_bag["readOnlyFill"] = rfill

    # Combo button width default
    if "combo" in groups:
        groups["combo"].setdefault("buttonWidth", 17)
    if "spin" in groups:
        groups["spin"].setdefault("buttonWidth", 15)

    # Tooltips / message box / focus defaults matching Luna fixture shape
    groups.setdefault(
        "toolTip",
        {"fill": "#FFFFE1", "border": "#000000", "text": "#000000"},
    )
    groups.setdefault("messageBox", {"minWidth": 280, "minHeight": 120})
    groups.setdefault("focusRect", {"color": "#000000"})

    fonts = {"ui": "Tahoma"}
    caption_font = sysm.get("menufont") or sysm.get("captionfont")
    if caption_font:
        fonts["ui"] = caption_font.split(",")[0].strip() or "Tahoma"

    display_name = name
    if not display_name:
        display_name = slug or root.name
        # Prefer INI stem color label
        stem = ini.stem.upper()
        if "HOMESTEAD" in stem:
            display_name = f"{root.name} Homestead"
        elif "METALLIC" in stem:
            display_name = f"{root.name} Metallic"
        elif "BLUE" in stem:
            display_name = f"{root.name} Blue"
        else:
            display_name = root.name

    # Start::Button that already paints its own logo (TrueSize / negative
    # contentLeft / tiny font) must not get the explorer flag composited on top.
    start_bag = groups.setdefault("startButton", {})
    start_bag["composeFlag"] = infer_compose_start_flag(start_bag)

    # Start flag is explorer/shell art (not in .msstyles). Prefer theme-local
    # explorer assets only when the Start button expects a separate flag.
    if start_bag.get("composeFlag"):
        if "startFlagImage" not in images:
            for candidate in (
                root / "explorer_assets" / "explorer" / "images" / "143.png",
                root / "assets" / "start_flag.png",
            ):
                if candidate.is_file():
                    images["startFlagImage"] = relative_image(root, candidate)
                    break
    else:
        images.pop("startFlagImage", None)

    required = [
        "buttonImage",
        "taskbarImage",
        "startButtonImage",
    ]
    for key in required:
        if key not in images:
            errors.append(f"required image missing: {key}")

    # Caption strip: frame 0 = active, frame 1 = inactive (XP Window.Caption).
    _derive_caption_frames(root, images, groups.get("caption") or {})

    doc: dict = {
        "name": display_name if not display_name.startswith("luna") else (
            "Windows XP Luna" if "Blue" in display_name or display_name == "luna"
            else display_name
        ),
        "generation": generation,
        "colors": colors,
        "sizes": sizes,
        "images": images,
        "fonts": fonts,
    }
    # Keep Luna fixture display name when projecting the checked-in theme.
    if root.name == "luna" and "BLUE" in ini.stem.upper():
        doc["name"] = "Windows XP Luna"

    for group_name, bag in groups.items():
        if bag:
            doc[group_name] = bag

    return doc, warnings, errors


_META_KEYS = frozenset(
    {
        "name",
        "generation",
        "activeScheme",
        "schemes",
        "schemeData",
        "sourceHash",
        "sourceFile",
    }
)


def variant_from_doc(document: dict) -> dict:
    """Visual payload for one scheme (everything except pack metadata)."""
    return {key: value for key, value in document.items() if key not in _META_KEYS}


def project_theme_pack(
    theme_root: str | Path,
    *,
    name: str | None = None,
    generation: str = "xp",
    slug: str | None = None,
    ini: str | None = None,
) -> tuple[dict, list[str], list[str]]:
    """Project every scheme INI into one theme.json with schemeData + active flatten."""
    from . import schemes as scheme_mod

    root = Path(theme_root).resolve()
    warnings: list[str] = []
    errors: list[str] = []
    scheme_list = scheme_mod.list_schemes(root)
    if not scheme_list:
        errors.append(
            "no scheme INI available to project "
            "(expected NORMAL*/LARGEFONTS*/EXTRALARGE* such as NORMALBLUE or NORMALDEFAULT)"
        )
        return {}, warnings, errors

    active_path = scheme_mod.resolve_scheme(root, ini)
    if active_path is None:
        errors.append("could not resolve active scheme INI")
        return {}, warnings, errors
    active_id = active_path.stem
    # Prefer the listed id casing when stems match case-insensitively.
    for entry in scheme_list:
        if entry["id"].upper() == active_id.upper():
            active_id = entry["id"]
            break

    pack_name = name or slug or root.name
    scheme_data: dict[str, dict] = {}
    for entry in scheme_list:
        doc, w, e = project_theme(
            root,
            entry["path"],
            name=pack_name,
            generation=generation,
            slug=slug or root.name,
        )
        warnings.extend(w)
        if e and not doc.get("images"):
            errors.extend(e)
            continue
        errors.extend(e)
        # Pack display name is stable; schemes are selected in Settings.
        doc["name"] = pack_name
        scheme_data[entry["id"]] = variant_from_doc(doc)

    if not scheme_data:
        return {}, warnings, errors or ["no scheme projected successfully"]

    if active_id not in scheme_data:
        active_id = next(iter(scheme_data))

    active_variant = scheme_data[active_id]
    pack: dict = {
        "name": pack_name,
        "generation": generation,
        "activeScheme": active_id,
        "schemes": [{"id": s["id"], "label": s["label"]} for s in scheme_list if s["id"] in scheme_data],
        "schemeData": scheme_data,
    }
    pack.update(active_variant)
    if root.name == "luna" and "BLUE" in active_id.upper() and not name:
        pack["name"] = "Windows XP Luna"
    return pack, warnings, errors


def write_theme_json(theme_root: str | Path, document: dict) -> Path:
    root = Path(theme_root)
    path = root / "theme.json"
    path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    return path


def infer_compose_start_flag(start_button: dict) -> bool:
    """Whether TaskBar should overlay the explorer Start flag on the button.

    Official Luna leaves a content gutter for the flag + "start" text. Many
    third-party styles (e.g. Concave) use TrueSize art with the logo baked in.
    """
    sizing = str(start_button.get("sizingType") or "stretch").lower().replace(" ", "")
    if sizing in ("truesize", "true_size"):
        return False
    content_left = start_button.get("contentLeft")
    if content_left is not None:
        try:
            if int(content_left) < 0:
                return False
        except (TypeError, ValueError):
            pass
    font_size = start_button.get("fontSize")
    if font_size is not None:
        try:
            if int(font_size) <= 1:
                return False
        except (TypeError, ValueError):
            pass
    return True


def default_start_flag_source() -> Path | None:
    """Bundled XP Start flag (explorer resource 143) next to the Luna fixture."""
    # scripts/quickxp_theme/project.py → repo root
    repo = Path(__file__).resolve().parents[2]
    candidate = (
        repo
        / "QuickXP"
        / "themes"
        / "luna"
        / "explorer_assets"
        / "explorer"
        / "images"
        / "143.png"
    )
    return candidate if candidate.is_file() else None


def ensure_start_flag(theme_root: str | Path, document: dict) -> dict:
    """Copy the default XP Start flag into the theme when missing.

    Real Windows XP draws the flag from explorer resources, not the .msstyles
    file. Themes whose Start art already includes a logo (composeFlag=false)
    must not receive this overlay.
    """
    images = document.setdefault("images", {})
    start = document.get("startButton")
    if not isinstance(start, dict):
        start = {}
        document["startButton"] = start
    if "composeFlag" not in start:
        start["composeFlag"] = infer_compose_start_flag(start)

    if not start.get("composeFlag"):
        images.pop("startFlagImage", None)
        _propagate_start_flag(document, None)
        return document

    if images.get("startFlagImage"):
        flag_path = Path(theme_root) / images["startFlagImage"]
        if flag_path.is_file():
            _propagate_start_flag(document, images["startFlagImage"])
            return document

    source = default_start_flag_source()
    if source is None:
        return document

    root = Path(theme_root)
    dest_dir = root / "assets"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "start_flag.png"
    if not dest.exists():
        dest.write_bytes(source.read_bytes())
    images["startFlagImage"] = "assets/start_flag.png"
    _propagate_start_flag(document, images["startFlagImage"])
    return document


def _propagate_start_flag(document: dict, relative: str | None) -> None:
    scheme_data = document.get("schemeData")
    if not isinstance(scheme_data, dict):
        return
    for variant in scheme_data.values():
        if not isinstance(variant, dict):
            continue
        images = variant.get("images")
        if not isinstance(images, dict):
            if relative is None:
                continue
            images = {}
            variant["images"] = images
        if relative:
            if not images.get("startFlagImage"):
                images["startFlagImage"] = relative
        else:
            images.pop("startFlagImage", None)
