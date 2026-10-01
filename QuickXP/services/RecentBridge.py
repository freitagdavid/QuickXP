#!/usr/bin/env python3
"""Recent documents from ~/.local/share/recently-used.xbel (+ optional GTK bookmarks).

CLI:
  RecentBridge.py recent [--limit N]
  RecentBridge.py favorites
  RecentBridge.py clear-recent
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlparse


def recent_path() -> Path:
    return Path.home() / ".local" / "share" / "recently-used.xbel"


def bookmarks_path() -> Path:
    return Path.home() / ".config" / "gtk-3.0" / "bookmarks"


def label_from_uri(uri: str) -> str:
    parsed = urlparse(uri)
    path = unquote(parsed.path or "")
    name = Path(path).name if path else uri
    return name or uri


def list_recent(limit: int = 15) -> list[dict]:
    path = recent_path()
    if not path.is_file():
        return []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return []

    out: list[dict] = []
    seen: set[str] = set()
    for bookmark in root.iter("bookmark"):
        href = (bookmark.get("href") or "").strip()
        if not href or href in seen:
            continue
        if not (href.startswith("file:") or href.startswith("/")):
            continue
        seen.add(href)
        out.append(
            {
                "kind": "action",
                "id": f"recent:{len(out)}",
                "action": "open-uri",
                "uri": href if href.startswith("file:") else "file://" + href,
                "label": label_from_uri(href),
                "icon": "text-x-generic",
                "mnemonic": "",
                "children": [],
            }
        )
        if len(out) >= max(1, limit):
            break
    return out


def list_favorites() -> list[dict]:
    path = bookmarks_path()
    if not path.is_file():
        return []
    out: list[dict] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(" ", 1)
        uri = parts[0]
        label = parts[1] if len(parts) > 1 else label_from_uri(uri)
        if not uri.startswith("file:"):
            continue
        out.append(
            {
                "kind": "action",
                "id": f"fav:{len(out)}",
                "action": "open-uri",
                "uri": uri,
                "label": label,
                "icon": "folder",
                "mnemonic": "",
                "children": [],
            }
        )
    return out


def clear_recent() -> dict:
    path = recent_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<xbel version="1.0"\n'
        '      xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks"\n'
        '      xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info"\n'
        '></xbel>\n',
        encoding="utf-8",
    )
    return {"ok": True, "path": str(path)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="QuickXP recent / favorites")
    parser.add_argument("mode", choices=("recent", "favorites", "clear-recent"))
    parser.add_argument("--limit", type=int, default=15)
    args = parser.parse_args(argv)

    if args.mode == "recent":
        json.dump(list_recent(args.limit), sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 0
    if args.mode == "favorites":
        json.dump(list_favorites(), sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 0
    json.dump(clear_recent(), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
