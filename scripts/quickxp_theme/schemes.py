"""List XP color/size scheme INI files under an extract tree."""

from __future__ import annotations

import re
from pathlib import Path

# Luna: NORMALBLUE / Homestead / Metallic; Zune & many packs: NORMALDEFAULT, etc.
SCHEME_RE = re.compile(
    r"^(NORMAL|LARGEFONTS|EXTRALARGE)([A-Z][A-Z0-9]*)$",
    re.IGNORECASE,
)

COLOR_LABELS = {
    "BLUE": "Blue",
    "HOMESTEAD": "Homestead",
    "METALLIC": "Metallic",
    "DEFAULT": "Default",
}

SIZE_LABELS = {
    "NORMAL": "Normal",
    "LARGEFONTS": "Large fonts",
    "EXTRALARGE": "Extra large",
}

SKIP_STEMS = frozenset({"THEMES", "DEFAULT"})


def _label(stem: str) -> str:
    match = SCHEME_RE.match(stem)
    if not match:
        return stem
    size_key = match.group(1).upper()
    color_key = match.group(2).upper()
    size = SIZE_LABELS.get(size_key, match.group(1))
    color = COLOR_LABELS.get(color_key, color_key.title())
    if size_key == "NORMAL":
        return color
    return f"{color} ({size})"


def _looks_like_scheme_ini(path: Path) -> bool:
    """Reject helper INIs; accept packs that define SysMetrics / control classes."""
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return False
    lower = text.lower()
    return "[sysmetrics]" in lower or "[button.pushbutton]" in lower or "[globals]" in lower


def _is_scheme_ini(stem: str) -> bool:
    upper = stem.upper()
    if upper in SKIP_STEMS:
        return False
    return SCHEME_RE.match(stem) is not None


def list_schemes(root: str | Path) -> list[dict]:
    """Return scheme descriptors sorted with primary Normal schemes first."""
    base = Path(root).resolve()
    found: dict[str, dict] = {}
    for path in base.rglob("*.ini"):
        stem = path.stem
        if not _is_scheme_ini(stem):
            continue
        if not _looks_like_scheme_ini(path):
            continue
        found[stem.upper()] = {
            "id": stem,
            "filename": path.name,
            "path": str(path),
            "relative": path.relative_to(base).as_posix(),
            "label": _label(stem),
        }

    preferred = [
        "NORMALBLUE",
        "NORMALDEFAULT",
        "NORMALNORMAL",  # e.g. Concave "Normal" size
        "NORMALHOMESTEAD",
        "NORMALMETALLIC",
    ]
    ordered: list[dict] = []
    for key in preferred:
        if key in found:
            ordered.append(found.pop(key))
    # Remaining NORMAL* before large-font variants
    normals = sorted(
        (k for k in found if k.startswith("NORMAL")),
        key=lambda k: k,
    )
    for key in normals:
        ordered.append(found.pop(key))
    ordered.extend(sorted(found.values(), key=lambda e: e["id"].upper()))
    return ordered


def resolve_scheme(root: str | Path, scheme: str | None = None) -> Path | None:
    """Pick an INI path by scheme id/filename; default first listed scheme."""
    schemes = list_schemes(root)
    if not schemes:
        return None
    if scheme:
        want = scheme.strip()
        want_upper = want.upper()
        for entry in schemes:
            if entry["id"].upper() == want_upper or entry["filename"].upper() == want_upper:
                return Path(entry["path"])
        candidate = Path(want)
        if candidate.is_file():
            return candidate.resolve()
        nested = Path(root) / want
        if nested.is_file():
            return nested.resolve()
        return None
    return Path(schemes[0]["path"])
