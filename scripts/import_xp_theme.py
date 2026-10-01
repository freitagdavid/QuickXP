#!/usr/bin/env python3
"""CLI for XP .msstyles import (JSON summary for Settings Process).

Examples:
  python3 scripts/import_xp_theme.py --probe path/to/Luna.msstyles
  python3 scripts/import_xp_theme.py --install path/to/Luna.msstyles \\
      --dest ~/.local/share/quickshell/.../themes --ini NORMALBLUE
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from quickxp_theme import pipeline


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--probe", action="store_true", help="detect + list schemes")
    mode.add_argument("--install", action="store_true", help="full import into --dest")
    mode.add_argument(
        "--project-only",
        action="store_true",
        help="project an existing extract tree to theme.json (no copy)",
    )
    parser.add_argument("path", type=Path, help=".msstyles file or extract directory")
    parser.add_argument("--dest", type=Path, help="install root (themes/ parent)")
    parser.add_argument(
        "--ini",
        help="active scheme id or INI filename (default: preferred Normal scheme)",
    )
    parser.add_argument("--slug", help="theme slug override")
    parser.add_argument("--name", help="display name override")
    parser.add_argument(
        "--force-generation",
        choices=("xp",),
        help="override detect (xp only for now)",
    )
    args = parser.parse_args(argv)

    if args.probe:
        payload = pipeline.probe(args.path)
    elif args.project_only:
        from quickxp_theme import project

        root = args.path.resolve()
        doc, warnings, errors = project.project_theme_pack(
            root,
            name=args.name,
            generation="xp",
            slug=args.slug or root.name,
            ini=args.ini,
        )
        out = project.write_theme_json(root, doc) if doc else None
        payload = {
            "ok": bool(doc) and not (errors and not (doc or {}).get("images")),
            "path": str(out) if out else None,
            "warnings": warnings,
            "errors": errors,
            "scheme": (doc or {}).get("activeScheme"),
            "schemes": (doc or {}).get("schemes", []),
            "theme": {
                "name": doc.get("name"),
                "imageCount": len(doc.get("images", {})),
            }
            if doc
            else None,
        }
    else:
        if args.dest is None:
            print(
                json.dumps(
                    {"ok": False, "errors": ["--dest is required for --install"]},
                    separators=(",", ":"),
                )
            )
            return 2
        payload = pipeline.import_theme(
            args.path,
            args.dest,
            ini=args.ini,
            slug=args.slug,
            name=args.name,
            force_generation=args.force_generation,
        )

    print(json.dumps(payload, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
