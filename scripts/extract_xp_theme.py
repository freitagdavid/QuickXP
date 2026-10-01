#!/usr/bin/env python3
"""CLI for extracting images and settings from a Windows XP visual style.

PATH is a theme directory, an .msstyles file, or a Shellstyle.dll.
The default PATH is the current directory. OUTPUT defaults to ./extracted
under PATH (or beside PATH, when PATH is a file).

Library: quickxp_theme.extract
"""

from pathlib import Path
import sys

# Allow `python scripts/extract_xp_theme.py` without installing the package.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from quickxp_theme.extract import main

if __name__ == "__main__":
    raise SystemExit(main())
