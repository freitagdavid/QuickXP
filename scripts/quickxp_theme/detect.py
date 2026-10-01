"""Detect visual-style generation (XP vs Vista+ vs unknown)."""

from __future__ import annotations

from pathlib import Path

from . import extract

XP_INI_MARKERS = (
    "[button.pushbutton]",
    "[button.checkbox]",
    "[sysmetrics]",
    "[taskbar.backgroundbottom]",
    "[start::button]",
)

VISTA_NAME_HINTS = (
    "aero",
    "aero.msstyles",
    "aerolite",
)


def _ini_text_signals(text: str) -> int:
    lower = text.lower()
    return sum(1 for marker in XP_INI_MARKERS if marker in lower)


def _scan_extract_tree(root: Path) -> dict:
    reasons: list[str] = []
    settings = list(root.rglob("*.ini"))
    bmps = list(root.rglob("*.bmp")) + list(root.rglob("*.BMP"))
    pngs = list(root.rglob("*.png")) + list(root.rglob("*.PNG"))
    tgas = list(root.rglob("*.tga")) + list(root.rglob("*.TGA"))

    ini_hits = 0
    for path in settings:
        try:
            ini_hits += _ini_text_signals(path.read_text(errors="replace"))
        except OSError:
            continue

    if settings:
        reasons.append(f"{len(settings)} ini file(s)")
    if ini_hits:
        reasons.append(f"{ini_hits} XP class marker hit(s)")
    if bmps:
        reasons.append(f"{len(bmps)} bmp asset(s)")
    if pngs and not bmps:
        reasons.append(f"{len(pngs)} png-only asset(s)")
    if tgas:
        reasons.append(f"{len(tgas)} tga asset(s)")

    return {
        "settings": len(settings),
        "ini_hits": ini_hits,
        "bmps": len(bmps),
        "pngs": len(pngs),
        "tgas": len(tgas),
        "reasons": reasons,
    }


def _scan_pe(path: Path) -> dict:
    reasons: list[str] = []
    data = path.read_bytes()
    textfiles = 0
    bitmaps = 0
    pngs = 0
    other_images = 0
    try:
        resources = list(extract.iter_resources(data))
    except ValueError as error:
        return {
            "textfiles": 0,
            "bitmaps": 0,
            "pngs": 0,
            "other_images": 0,
            "reasons": [f"PE parse failed: {error}"],
            "error": str(error),
        }

    for ident, blob in resources:
        restype = ident[0]
        if restype in extract.TEXT_TYPES or (
            isinstance(restype, str) and restype.upper() in extract.TEXT_TYPES
        ):
            textfiles += 1
            text = extract.decode_text(blob)
            if text and _ini_text_signals(text):
                reasons.append("TEXTFILE contains XP class sections")
            continue
        if restype == extract.RT_BITMAP:
            bitmaps += 1
            continue
        ext = extract.image_extension(blob)
        if ext == ".png":
            pngs += 1
        elif ext:
            other_images += 1

    if textfiles:
        reasons.append(f"{textfiles} TEXTFILE/UIFILE resource(s)")
    if bitmaps:
        reasons.append(f"{bitmaps} RT_BITMAP resource(s)")
    if pngs:
        reasons.append(f"{pngs} embedded PNG resource(s)")
    if other_images:
        reasons.append(f"{other_images} other image resource(s)")

    name = path.name.lower()
    for hint in VISTA_NAME_HINTS:
        if hint in name:
            reasons.append(f"filename hint: {hint}")

    return {
        "textfiles": textfiles,
        "bitmaps": bitmaps,
        "pngs": pngs,
        "other_images": other_images,
        "reasons": reasons,
    }


def _classify(tree: dict | None, pe: dict | None, name_hint: str) -> dict:
    reasons: list[str] = []
    if tree:
        reasons.extend(tree.get("reasons", []))
    if pe:
        reasons.extend(pe.get("reasons", []))

    xp_score = 0
    vista_score = 0

    if tree:
        xp_score += min(tree["ini_hits"], 6)
        xp_score += 2 if tree["bmps"] >= 5 else (1 if tree["bmps"] else 0)
        if tree["pngs"] and not tree["bmps"] and tree["ini_hits"] == 0:
            vista_score += 4
        if tree["tgas"]:
            vista_score += 3

    if pe:
        xp_score += 3 if pe["textfiles"] else 0
        xp_score += 2 if pe["bitmaps"] >= 5 else (1 if pe["bitmaps"] else 0)
        if pe["pngs"] >= 5 and pe["textfiles"] == 0:
            vista_score += 5
        elif pe["pngs"] and pe["bitmaps"] == 0 and pe["textfiles"] == 0:
            vista_score += 4

    lower = name_hint.lower()
    if any(h in lower for h in VISTA_NAME_HINTS):
        vista_score += 2

    if xp_score >= 3 and xp_score > vista_score:
        generation = "xp"
        confidence = min(0.95, 0.45 + 0.08 * xp_score)
    elif vista_score >= 3 and vista_score > xp_score:
        generation = "vista"
        confidence = min(0.9, 0.4 + 0.1 * vista_score)
        if "win7" in lower or "aero" in lower:
            # Aero ships on both; keep vista unless name says 7.
            if "7" in lower or "win7" in lower:
                generation = "win7"
    elif xp_score > 0 and vista_score == 0:
        generation = "xp"
        confidence = 0.4
    else:
        generation = "unknown"
        confidence = 0.2
        reasons.append("insufficient XP/Vista signals")

    return {
        "generation": generation,
        "confidence": round(confidence, 2),
        "reasons": reasons,
        "xp_score": xp_score,
        "vista_score": vista_score,
    }


def detect(path: str | Path) -> dict:
    """Return generation info for an .msstyles file, folder, or extract tree."""
    root = Path(path).resolve()
    if not root.exists():
        return {
            "generation": "unknown",
            "confidence": 0.0,
            "reasons": [f"path does not exist: {root}"],
            "path": str(root),
        }

    tree = None
    pe = None
    name_hint = root.name

    if root.is_file():
        name_hint = root.name
        if root.suffix.lower() == ".msstyles" or root.name.lower() == "shellstyle.dll":
            pe = _scan_pe(root)
        else:
            return {
                "generation": "unknown",
                "confidence": 0.0,
                "reasons": [f"unsupported file type: {root.name}"],
                "path": str(root),
            }
    else:
        # Prefer nested extract (images/ + settings/) or any INI tree.
        tree = _scan_extract_tree(root)
        # Also probe a single .msstyles under the folder if present.
        styles = sorted(root.rglob("*.msstyles"))
        if styles:
            name_hint = styles[0].name
            pe = _scan_pe(styles[0])

    result = _classify(tree, pe, name_hint)
    result["path"] = str(root)
    return result
