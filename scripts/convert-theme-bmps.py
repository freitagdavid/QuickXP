#!/usr/bin/env python3
"""CLI for converting visual-style BMP assets into transparent PNGs.

Library: quickxp_theme.convert
"""

from pathlib import Path
import sys

# Allow `python scripts/convert-theme-bmps.py` without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from quickxp_theme.convert import main

if __name__ == "__main__":
    raise SystemExit(main())
