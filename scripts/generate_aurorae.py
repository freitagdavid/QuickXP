#!/usr/bin/env python3
"""Generate / regenerate Aurorae package for an installed QuickXP theme.

Examples:
  python3 scripts/generate_aurorae.py QuickXP/themes/luna
  python3 scripts/generate_aurorae.py ~/.local/share/quickshell/.../themes/candy
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from quickxp_theme import aurorae


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="theme root containing theme.json / extract")
    parser.add_argument("--slug", help="theme slug override (default: directory name)")
    parser.add_argument("--ini", help="scheme id when reprojection is needed")
    args = parser.parse_args(argv)
    payload = aurorae.generate_for_theme_root(
        args.path,
        slug=args.slug,
        ini=args.ini,
    )
    print(json.dumps(payload, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
