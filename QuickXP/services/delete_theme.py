#!/usr/bin/env python3
"""Delete a user-installed QuickXP theme (JSON for Settings Process).

Usage:
  delete_theme.py --dest THEMES_ROOT SLUG
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path


def delete_theme(install_root: Path, slug: str) -> dict:
    root = install_root.resolve()
    if not root.is_dir():
        return {"ok": False, "errors": [f"themes root does not exist: {root}"]}

    clean = slug.strip().strip("/\\")
    if not clean or clean in (".", "..") or "/" in clean or "\\" in clean:
        return {"ok": False, "errors": ["invalid theme slug"]}

    target = (root / clean).resolve()
    try:
        target.relative_to(root)
    except ValueError:
        return {"ok": False, "errors": ["refusing to delete path outside themes root"]}

    if target == root:
        return {"ok": False, "errors": ["refusing to delete themes root"]}

    if not target.is_dir() or not (target / "theme.json").is_file():
        return {"ok": False, "errors": [f"theme not found: {clean}"]}

    shutil.rmtree(target)
    return {"ok": True, "slug": clean, "path": str(target)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dest", type=Path, required=True, help="user themes root")
    parser.add_argument("slug", help="theme directory name under --dest")
    args = parser.parse_args(argv)
    payload = delete_theme(args.dest, args.slug)
    print(json.dumps(payload, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
