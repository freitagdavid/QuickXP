"""Decode Vista/7 .msstyles property stores (CMAP, VMAP, VARIANT, IMAGE).

The record layout matches the msstyleEditor / libmsstyle description of the
Aero property store. Windows 7 uses the same records; only the class map
differs. Class ids are 0-based indexes into the 8-byte-aligned CMAP.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass, field
from pathlib import Path

from . import extract

# Primitive type ids (vssym32.h).
TMT_ENUM = 200
TMT_STRING = 201
TMT_INT = 202
TMT_BOOL = 203
TMT_COLOR = 204
TMT_MARGINS = 205
TMT_FILENAME = 206
TMT_SIZE = 207
TMT_POSITION = 208
TMT_RECT = 209
TMT_FONT = 210
TMT_INTLIST = 211
TMT_BITMAPREF = 215

# Property name ids the projector reads. Unknown ids stay as TMT_<n>.
PROP_NAMES = {
    801: "CAPTIONFONT",
    1201: "SIZINGBORDERWIDTH",
    1202: "SCROLLBARWIDTH",
    1204: "CAPTIONBARWIDTH",
    1205: "CAPTIONBARHEIGHT",
    1206: "SMCAPTIONBARWIDTH",
    1207: "SMCAPTIONBARHEIGHT",
    1210: "PADDEDBORDERWIDTH",
    1601: "SCROLLBAR",
    1602: "BACKGROUND",
    1603: "ACTIVECAPTION",
    1604: "INACTIVECAPTION",
    1605: "MENU",
    1606: "WINDOW",
    1608: "MENUTEXT",
    1609: "WINDOWTEXT",
    1610: "CAPTIONTEXT",
    1614: "HIGHLIGHT",
    1615: "HIGHLIGHTTEXT",
    1616: "BTNFACE",
    1619: "BTNTEXT",
    1620: "INACTIVECAPTIONTEXT",
    2204: "COMPOSITED",
    2401: "IMAGECOUNT",
    2404: "ROUNDCORNERWIDTH",
    2405: "ROUNDCORNERHEIGHT",
    2425: "TEXTGLOWSIZE",
    2429: "GLOWINTENSITY",
    2430: "OPACITY",
    2431: "COLORIZATIONCOLOR",
    2432: "COLORIZATIONOPACITY",
    3001: "IMAGEFILE",
    3002: "IMAGEFILE1",
    3003: "IMAGEFILE2",
    3004: "IMAGEFILE3",
    3005: "IMAGEFILE4",
    3006: "IMAGEFILE5",
    3008: "GLYPHIMAGEFILE",
    3401: "OFFSET",
    3402: "TEXTSHADOWOFFSET",
    3601: "SIZINGMARGINS",
    213: "ATLASIMAGE",
    3602: "CONTENTMARGINS",
    3603: "CAPTIONMARGINS",
    8002: "ATLASRECT",
    3801: "BORDERCOLOR",
    3802: "FILLCOLOR",
    3803: "TEXTCOLOR",
    3804: "EDGELIGHTCOLOR",
    3805: "EDGEHIGHLIGHTCOLOR",
    3806: "EDGESHADOWCOLOR",
    3807: "EDGEDKSHADOWCOLOR",
    3815: "SHADOWCOLOR",
    3816: "GLOWCOLOR",
    3818: "TEXTSHADOWCOLOR",
    3821: "FILLCOLORHINT",
    3822: "BORDERCOLORHINT",
    3823: "ACCENTCOLORHINT",
    4001: "BGTYPE",
    4004: "SIZINGTYPE",
    4008: "OFFSETTYPE",
    4011: "IMAGELAYOUT",
}

HEADER_SIZE = 32


@dataclass
class Prop:
    name: str
    kind: str
    value: object
    # High byte of a COLORIZATIONCOLOR DWORD. None for ordinary colors.
    alpha: int | None = None


@dataclass
class AeroVariant:
    """One VARIANT resource (a color/size combination)."""

    resource_name: str
    # class name -> part id -> state id -> prop name -> Prop
    classes: dict[str, dict[int, dict[int, dict[str, Prop]]]] = field(default_factory=dict)


@dataclass
class AeroFile:
    class_names: list[str]
    vmap: list[str]
    variants: list[AeroVariant]
    images: dict[int, bytes]
    streams: dict[int, bytes] = field(default_factory=dict)
    file_version: str = ""

    def variant(self, resource_name: str | None = None) -> AeroVariant | None:
        if not self.variants:
            return None
        if resource_name:
            for item in self.variants:
                if item.resource_name.lower() == resource_name.lower():
                    return item
        return self.variants[0]


def prop_name(name_id: int) -> str:
    return PROP_NAMES.get(name_id, f"TMT_{name_id}")


def parse_cmap(blob: bytes) -> list[str]:
    """Null-terminated UTF-16 class names, each record padded to 8 bytes."""
    names: list[str] = []
    index = 0
    size = len(blob)
    while index + 1 < size:
        chars: list[str] = []
        while index + 1 < size:
            unit = struct.unpack_from("<H", blob, index)[0]
            index += 2
            if unit == 0:
                break
            chars.append(chr(unit))
        if not chars and index >= size:
            break
        names.append("".join(chars))
        if index % 8:
            index += 8 - (index % 8)
    while names and names[-1] == "":
        names.pop()
    return names


def parse_vmap(blob: bytes) -> list[str]:
    """Length-prefixed UTF-16 names (count includes the trailing NUL), 4-byte padded."""
    names: list[str] = []
    index = 0
    size = len(blob)
    while index + 4 <= size:
        count = struct.unpack_from("<I", blob, index)[0]
        index += 4
        nbytes = count * 2
        if count == 0 or index + nbytes > size:
            break
        text = blob[index:index + nbytes].decode("utf-16le", errors="replace").rstrip("\x00")
        index += nbytes
        if index % 4:
            index += 4 - (index % 4)
        if text:
            names.append(text)
    return names


def _pad_span(header_and_data: int) -> int:
    return (8 - (header_and_data % 8)) % 8


def parse_variant(blob: bytes, class_names: list[str]) -> AeroVariant:
    """Walk VARIANT records into a class/part/state tree."""
    tree: dict[str, dict[int, dict[int, dict[str, Prop]]]] = {}
    index = 0
    size = len(blob)
    while index + HEADER_SIZE <= size:
        name_id, type_id, class_id, part_id, state_id, short_flag, _reserved, data_size = (
            struct.unpack_from("<8i", blob, index)
        )
        payload = b""
        if short_flag == 0:
            data_size = max(data_size, 0)
            payload = blob[index + HEADER_SIZE:index + HEADER_SIZE + data_size]
            span = HEADER_SIZE + data_size
            index += span + _pad_span(span)
        else:
            index += HEADER_SIZE
        if class_id < 0 or class_id >= len(class_names):
            continue
        prop = _decode_prop(name_id, type_id, short_flag, payload)
        if prop is None:
            continue
        cname = class_names[class_id]
        tree.setdefault(cname, {}).setdefault(part_id, {}).setdefault(state_id, {})[prop.name] = prop
    return AeroVariant(resource_name="", classes=tree)


def _decode_prop(name_id: int, type_id: int, short_flag: int, payload: bytes) -> Prop | None:
    name = prop_name(name_id)
    if type_id in (TMT_INT, TMT_SIZE, TMT_ENUM, TMT_BOOL) or name_id == 2431:
        if name_id == 2431 and type_id == TMT_INT:
            raw = short_flag if short_flag else _i32(payload)
            if raw is None:
                return None
            rgb, alpha = colorization_channels(raw)
            return Prop(name, "color", rgb, alpha=alpha)
        value = short_flag if short_flag else _i32(payload)
        if value is None:
            return None
        if type_id == TMT_BOOL:
            return Prop(name, "bool", bool(value))
        if type_id == TMT_ENUM:
            return Prop(name, "enum", int(value))
        return Prop(name, "int", int(value))
    if type_id == TMT_COLOR:
        if short_flag:
            raw = struct.pack("<I", short_flag & 0xFFFFFFFF)
            return Prop(name, "color", _bgra_hex(raw))
        if len(payload) >= 4:
            return Prop(name, "color", _bgra_hex(payload))
        return None
    if type_id == TMT_MARGINS:
        if len(payload) < 16:
            return None
        left, right, top, bottom = struct.unpack_from("<4i", payload)
        return Prop(name, "margins", (left, right, top, bottom))
    if type_id in (TMT_FILENAME, TMT_BITMAPREF):
        image_id = short_flag if short_flag else _i32(payload)
        if not image_id:
            return None
        return Prop(name, "image", int(image_id))
    if type_id == TMT_POSITION:
        if short_flag:
            return Prop(name, "position", (short_flag, 0))
        if len(payload) < 8:
            return None
        x, y = struct.unpack_from("<2i", payload)
        return Prop(name, "position", (x, y))
    if type_id == TMT_STRING and payload:
        text = payload.decode("utf-16le", errors="replace").rstrip("\x00")
        return Prop(name, "string", text) if text else None
    if type_id == TMT_RECT:
        if len(payload) < 16:
            return None
        left, top, right, bottom = struct.unpack_from("<4i", payload)
        return Prop(name, "rect", (left, top, right, bottom))
    # DWMWindow atlas sheets are type 213. The short flag is the STREAM id.
    if type_id == 213:
        image_id = short_flag if short_flag else _i32(payload)
        if not image_id:
            return None
        return Prop(name, "image", int(image_id))
    return None


def _i32(payload: bytes) -> int | None:
    if len(payload) < 4:
        return None
    return struct.unpack_from("<i", payload)[0]


def _bgra_hex(payload: bytes) -> str:
    blue, green, red = payload[0], payload[1], payload[2]
    return f"#{red:02X}{green:02X}{blue:02X}"


def colorization_channels(value: int) -> tuple[str, int]:
    """Aero ColorizationColor DWORD is 0xAARRGGBB. The alpha byte is kept."""
    unsigned = value & 0xFFFFFFFF
    alpha = (unsigned >> 24) & 0xFF
    red = (unsigned >> 16) & 0xFF
    green = (unsigned >> 8) & 0xFF
    blue = unsigned & 0xFF
    return f"#{red:02X}{green:02X}{blue:02X}", alpha


def colorization_to_hex(value: int) -> str:
    """RGB half of a ColorizationColor DWORD. Prefer colorization_channels."""
    rgb, _alpha = colorization_channels(value)
    return rgb


def file_version_from_blob(blob: bytes) -> str:
    """Pull a 6.x / 10.x file version out of a VS_VERSION_INFO resource."""
    for needle in ("10.0.", "6.3.", "6.2.", "6.1.", "6.0."):
        if needle.encode("utf-16le") in blob:
            return needle[:-1]
    return ""


def load(path: str | Path) -> AeroFile:
    """Load an .msstyles (or Shellstyle.dll) Aero property store."""
    source = Path(path)
    resources = list(extract.iter_resources(source.read_bytes()))
    cmap = b""
    vmap = b""
    variants: list[tuple[str, bytes]] = []
    images: dict[int, bytes] = {}
    streams: dict[int, bytes] = {}
    version = ""
    for ident, blob in resources:
        restype = ident[0]
        name = ident[1] if len(ident) > 1 else ""
        if restype == "CMAP":
            cmap = blob
        elif restype == "VMAP":
            vmap = blob
        elif restype == "VARIANT":
            variants.append((str(name), blob))
        elif restype == "IMAGE" and isinstance(name, int):
            images[name] = blob
        elif restype == "STREAM" and isinstance(name, int):
            streams[name] = blob
        elif restype == extract.RT_VERSION or restype == 16:
            found = file_version_from_blob(blob)
            if found:
                version = found
    names = parse_cmap(cmap) if cmap else []
    parsed: list[AeroVariant] = []
    for resource_name, blob in variants:
        variant = parse_variant(blob, names)
        variant.resource_name = resource_name
        parsed.append(variant)
    return AeroFile(
        class_names=names,
        vmap=parse_vmap(vmap) if vmap else [],
        variants=parsed,
        images=images,
        streams=streams,
        file_version=version,
    )


def class_chain(name: str) -> list[str]:
    """`Derived::Base` inherits Base. The derived name is searched first."""
    chain = [name]
    if "::" in name:
        base = name.split("::", 1)[1]
        if base and base not in chain:
            chain.append(base)
    return chain


def lookup(
    variant: AeroVariant,
    classes: list[str],
    part: int,
    prop: str,
    state: int = 0,
    *,
    inherit_common: bool = True,
) -> Prop | None:
    """First matching property, walking preferred classes then :: bases.

    A non-zero state falls back to the common state (0) on the same part
    unless inherit_common is false.
    """
    for cname in classes:
        for link in class_chain(cname):
            parts = variant.classes.get(link)
            if not parts:
                continue
            states = parts.get(part)
            if not states:
                continue
            bag = states.get(state) or {}
            found = bag.get(prop)
            if found is None and state != 0 and inherit_common:
                found = (states.get(0) or {}).get(prop)
            if found is not None:
                return found
    return None
