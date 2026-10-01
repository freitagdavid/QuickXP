#!/usr/bin/env python3
"""List installed QuickXP themes as JSON for ThemeRegistry.qml.

Usage:
  list_themes.py [-o OUT.json] ROOT [ROOT ...]

Earlier roots win on slug collision (shell builtins before user data).
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys


def scan(root: pathlib.Path, *, deletable: bool = False) -> list:
    out = []
    if not root.is_dir():
        return out
    for path in sorted(p for p in root.iterdir() if p.is_dir()):
        theme_json = path / "theme.json"
        if not theme_json.is_file():
            continue
        try:
            data = json.loads(theme_json.read_text(encoding="utf-8"))
        except Exception:
            data = {}
        if not isinstance(data, dict):
            data = {}
        schemes = data.get("schemes", []) if isinstance(data.get("schemes"), list) else []
        scheme_data = (
            data.get("schemeData", {}) if isinstance(data.get("schemeData"), dict) else {}
        )
        out.append(
            {
                "slug": path.name,
                "name": data.get("name", path.name),
                "generation": data.get("generation", ""),
                "path": str(path),
                "deletable": deletable,
                "sourceHash": data.get("sourceHash", "") or "",
                "activeScheme": data.get("activeScheme", "") or "",
                "schemes": schemes,
                "schemeData": scheme_data,
                "hasAurorae": (path / "aurorae" / "decoration.svg").is_file()
                or (path / "aurorae" / "metadata.desktop").is_file(),
                "images": data.get("images", {}) if isinstance(data.get("images"), dict) else {},
                "colors": data.get("colors", {}) if isinstance(data.get("colors"), dict) else {},
                "sizes": data.get("sizes", {}) if isinstance(data.get("sizes"), dict) else {},
            }
        )
    return out


def scan_many(roots: list[pathlib.Path]) -> list:
    """Earlier roots win on slug collision (shell builtins before user data).

    Themes from roots after the first are marked deletable (user-data installs).
    """
    seen: set[str] = set()
    out: list = []
    for index, root in enumerate(roots):
        for theme in scan(root, deletable=index > 0):
            if theme["slug"] in seen:
                continue
            seen.add(theme["slug"])
            out.append(theme)
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--output",
        type=pathlib.Path,
        help="write JSON to this path instead of stdout",
    )
    parser.add_argument(
        "roots",
        nargs="+",
        type=pathlib.Path,
        help="theme root directories (shell first, then user data)",
    )
    # Backward compatible: list_themes.py ROOT [OUT]
    # If the last arg looks like a .json file and -o was not given, treat as output.
    raw = list(argv) if argv is not None else sys.argv[1:]
    if (
        "-o" not in raw
        and "--output" not in raw
        and len(raw) >= 2
        and str(raw[-1]).endswith(".json")
    ):
        out = pathlib.Path(raw[-1])
        roots = [pathlib.Path(a) for a in raw[:-1]]
        payload = json.dumps(scan_many(roots), separators=(",", ":"))
        _write_atomic(out, payload + "\n")
        return 0

    args = parser.parse_args(raw)
    payload = json.dumps(scan_many(args.roots), separators=(",", ":"))
    if args.output is not None:
        _write_atomic(args.output, payload + "\n")
    else:
        print(payload)
    return 0


def _write_atomic(path: pathlib.Path, text: str) -> None:
    """Write via tempfile + replace so readers never see a partial index."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(path)


if __name__ == "__main__":
    raise SystemExit(main())
