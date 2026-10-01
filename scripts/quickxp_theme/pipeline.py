"""Orchestrate XP theme import: detect → extract → convert → project → install."""

from __future__ import annotations

import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path

from . import convert, detect, extract, project, schemes


def sanitize_slug(value: str) -> str:
    text = value.strip().lower()
    text = re.sub(r"[^a-z0-9._-]+", "-", text)
    text = text.strip(".-")
    return text or "theme"


def unique_slug(install_root: Path, base: str) -> str:
    slug = sanitize_slug(base)
    if not (install_root / slug).exists():
        return slug
    for n in range(2, 1000):
        candidate = f"{slug}-{n}"
        if not (install_root / candidate).exists():
            return candidate
    raise RuntimeError(f"too many themes named {slug}")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_sha256(root: Path) -> str:
    """Stable content hash of an extract tree (paths + file digests)."""
    digest = hashlib.sha256()
    base = root.resolve()
    for path in sorted(p for p in base.rglob("*") if p.is_file()):
        rel = path.relative_to(base).as_posix().encode("utf-8")
        digest.update(rel)
        digest.update(b"\0")
        digest.update(file_sha256(path).encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def source_content_hash(style: Path | None, source: Path) -> str:
    """Hash identifying an importable visual style for reimport overwrite."""
    if style is not None and style.is_file():
        return "sha256:" + file_sha256(style)
    if source.is_dir():
        return "sha256:" + tree_sha256(source)
    if source.is_file():
        return "sha256:" + file_sha256(source)
    return ""


def find_slug_by_source_hash(install_root: Path, content_hash: str) -> str | None:
    """Return installed theme slug whose theme.json sourceHash matches."""
    if not content_hash or not install_root.is_dir():
        return None
    for path in sorted(p for p in install_root.iterdir() if p.is_dir()):
        theme_json = path / "theme.json"
        if not theme_json.is_file():
            continue
        try:
            data = json.loads(theme_json.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if isinstance(data, dict) and data.get("sourceHash") == content_hash:
            return path.name
    return None


def resolve_install_slug(
    install_root: Path,
    base: str,
    content_hash: str,
    *,
    forced_slug: str | None = None,
) -> tuple[str, bool]:
    """Pick slug for install. Returns (slug, replaced_existing)."""
    existing = find_slug_by_source_hash(install_root, content_hash)
    if existing:
        return existing, True
    if forced_slug is not None:
        slug = sanitize_slug(forced_slug)
        return slug, (install_root / slug).exists()
    slug = sanitize_slug(base)
    if (install_root / slug).exists():
        # Same folder name, different content — keep the old pack and add a sibling.
        return unique_slug(install_root, slug), False
    return slug, False


_GENERIC_PACK_DIRS = frozenset(
    {"", ".", "shell", "system32", "resources", "vs", "visual styles", "themes"}
)


def pack_base_name(source: Path, style: Path | None) -> str:
    """Human pack name: folder when present, else .msstyles stem."""
    if source.is_dir():
        return source.name
    if style is not None:
        parent = style.parent.name
        if parent and parent.lower() not in _GENERIC_PACK_DIRS:
            return parent
        return style.stem
    return source.stem


def extract_msstyles(msstyles: Path, work_dir: Path) -> Path:
    """Extract into work_dir/<stem>/ and return that directory."""
    work_dir.mkdir(parents=True, exist_ok=True)
    dest = work_dir / msstyles.stem
    if dest.exists():
        shutil.rmtree(dest)
    extract.extract_file(msstyles, dest)
    return dest


def find_msstyles(path: Path) -> Path | None:
    """Resolve a file or theme folder to a single .msstyles path."""
    if path.is_file():
        name = path.name.lower()
        if name.endswith(".msstyles") or name == "shellstyle.dll":
            return path
        return None
    if not path.is_dir():
        return None
    matches = sorted(path.rglob("*.msstyles"))
    if not matches:
        return None
    # Prefer a style in the folder itself over nested copies.
    top = [m for m in matches if m.parent == path]
    return (top or matches)[0]


def probe(path: str | Path) -> dict:
    """Detect generation and list color schemes (no install)."""
    source = Path(path).resolve()
    style = find_msstyles(source)
    info = detect.detect(style or source)
    result = {
        "ok": True,
        "path": str(style or source),
        "generation": info["generation"],
        "confidence": info["confidence"],
        "reasons": info.get("reasons", []),
        "schemes": [],
        "errors": [],
        "warnings": [],
    }
    if info["generation"] not in ("xp",):
        result["ok"] = False
        result["errors"].append(
            f"unsupported generation '{info['generation']}' for XP import "
            "(Vista/7 projection is not available yet)"
        )
        return result

    # Extract .msstyles (or use an already-extracted tree) to list schemes.
    if style is not None:
        with tempfile.TemporaryDirectory(prefix="quickxp-probe-") as tmp:
            extracted = extract_msstyles(style, Path(tmp))
            result["schemes"] = schemes.list_schemes(extracted)
    else:
        result["schemes"] = schemes.list_schemes(source)

    if not result["schemes"]:
        result["warnings"].append(
            "no color scheme INI files found "
            "(expected NORMAL*/LARGEFONTS*/EXTRALARGE* such as NORMALBLUE or NORMALDEFAULT)"
        )
    return result


def import_theme(
    path: str | Path,
    install_root: str | Path,
    *,
    ini: str | None = None,
    slug: str | None = None,
    name: str | None = None,
    force_generation: str | None = None,
) -> dict:
    """Full XP import into install_root/<slug>/."""
    source = Path(path).resolve()
    dest_root = Path(install_root).resolve()
    dest_root.mkdir(parents=True, exist_ok=True)

    result: dict = {
        "ok": False,
        "slug": None,
        "path": None,
        "generation": None,
        "warnings": [],
        "errors": [],
        "schemes": [],
    }

    if not source.exists():
        result["errors"].append(f"path does not exist: {source}")
        return result

    style = find_msstyles(source)
    content_hash = source_content_hash(style, source)
    info = detect.detect(style or source)
    generation = force_generation or info["generation"]
    result["generation"] = generation
    result["detect"] = info
    result["sourceHash"] = content_hash

    if generation != "xp":
        result["errors"].append(
            f"unsupported generation '{generation}' for XP import "
            "(Vista/7 projection is not available yet)"
        )
        return result

    with tempfile.TemporaryDirectory(prefix="quickxp-import-") as tmp:
        tmp_path = Path(tmp)
        if style is not None:
            extracted = extract_msstyles(style, tmp_path / "extract")
        else:
            # Treat directory as an already-extracted tree.
            extracted = tmp_path / "extract" / (slug or source.name)
            shutil.copytree(source, extracted, dirs_exist_ok=True)

        converted, keyed, failed = convert.convert_tree(extracted)
        if failed:
            result["warnings"].extend(failed[:20])
            if len(failed) > 20:
                result["warnings"].append(f"…and {len(failed) - 20} more convert errors")
        result["converted"] = converted
        result["keyed_pixels"] = keyed

        pack = name or pack_base_name(source, style)
        final_slug, replaced = resolve_install_slug(
            dest_root,
            pack,
            content_hash,
            forced_slug=slug,
        )
        install_dir = dest_root / final_slug
        if install_dir.exists():
            shutil.rmtree(install_dir)
        shutil.copytree(extracted, install_dir)

        doc, warnings, errors = project.project_theme_pack(
            install_dir,
            name=pack,
            generation=generation,
            slug=final_slug,
            ini=ini,
        )
        result["warnings"].extend(warnings)
        result["errors"].extend(errors)
        result["schemes"] = doc.get("schemes", []) if doc else []

        if errors and not (doc and doc.get("images")):
            shutil.rmtree(install_dir, ignore_errors=True)
            return result

        doc = project.ensure_start_flag(install_dir, doc)
        if content_hash:
            doc["sourceHash"] = content_hash
        if style is not None:
            doc["sourceFile"] = style.name
        elif source.is_dir():
            doc["sourceFile"] = source.name
        project.write_theme_json(install_dir, doc)

        result["ok"] = True
        result["slug"] = final_slug
        result["replaced"] = replaced
        result["path"] = str(install_dir)
        result["scheme"] = doc.get("activeScheme")
        result["theme"] = {
            "name": doc.get("name"),
            "generation": doc.get("generation"),
            "imageCount": len(doc.get("images", {})),
        }
        result["entry"] = _registry_entry(final_slug, install_dir, doc)
        return result


def _registry_entry(slug: str, install_dir: Path, doc: dict) -> dict:
    return {
        "slug": slug,
        "name": doc.get("name", slug),
        "generation": doc.get("generation", "xp"),
        "path": str(install_dir),
        "sourceHash": doc.get("sourceHash", ""),
        "activeScheme": doc.get("activeScheme", ""),
        "schemes": doc.get("schemes", []) if isinstance(doc.get("schemes"), list) else [],
        "schemeData": doc.get("schemeData", {}) if isinstance(doc.get("schemeData"), dict) else {},
        "images": doc.get("images", {}) if isinstance(doc.get("images"), dict) else {},
        "colors": doc.get("colors", {}) if isinstance(doc.get("colors"), dict) else {},
        "sizes": doc.get("sizes", {}) if isinstance(doc.get("sizes"), dict) else {},
    }


def result_json(payload: dict) -> str:
    return json.dumps(payload, separators=(",", ":"))
