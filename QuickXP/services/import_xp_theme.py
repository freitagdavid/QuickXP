#!/usr/bin/env python3
"""Settings-facing entry for XP theme import.

Lives under QuickXP/services so Quickshell.shellPath resolves when
~/.config/quickshell/default/QuickXP is symlinked to the repo. Delegates to
repo scripts/import_xp_theme.py + quickxp_theme/.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
_SCRIPTS = _REPO_ROOT / "scripts"
_CLI = _SCRIPTS / "import_xp_theme.py"


def main(argv: list[str] | None = None) -> int:
    if not _CLI.is_file():
        print(
            '{"ok":false,"errors":["import CLI missing at '
            + str(_CLI).replace("\\", "\\\\").replace('"', '\\"')
            + '"]}',
        )
        return 1
    sys.path.insert(0, str(_SCRIPTS))
    spec = importlib.util.spec_from_file_location("quickxp_import_xp_theme_cli", _CLI)
    if spec is None or spec.loader is None:
        print('{"ok":false,"errors":["failed to load import CLI"]}')
        return 1
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return int(module.main(argv))


if __name__ == "__main__":
    raise SystemExit(main())
