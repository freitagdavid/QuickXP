#!/usr/bin/env python3
"""List installed QuickXP themes as JSON for ThemeRegistry.qml."""

from __future__ import annotations

import json
import pathlib
import sys


def scan(root: pathlib.Path) -> list:
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
        out.append(
            {
                "slug": path.name,
                "name": data.get("name", path.name),
                "generation": data.get("generation", ""),
                "path": str(path),
                "images": data.get("images", {}) if isinstance(data.get("images"), dict) else {},
                "colors": data.get("colors", {}) if isinstance(data.get("colors"), dict) else {},
                "sizes": data.get("sizes", {}) if isinstance(data.get("sizes"), dict) else {},
            }
        )
    return out


def main() -> int:
    root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path()
    payload = json.dumps(scan(root), separators=(",", ":"))
    if len(sys.argv) > 2:
        out_path = pathlib.Path(sys.argv[2])
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
