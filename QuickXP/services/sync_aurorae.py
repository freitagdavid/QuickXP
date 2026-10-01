#!/usr/bin/env python3
"""Install a QuickXP Aurorae package and select it in KWin (JSON for Settings).

Usage:
  sync_aurorae.py --theme-root PATH/TO/themes/luna
  sync_aurorae.py --theme-root PATH --install-only
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def aurorae_home() -> Path:
    xdg = os.environ.get("XDG_DATA_HOME")
    if xdg:
        return Path(xdg) / "aurorae" / "themes"
    return Path.home() / ".local" / "share" / "aurorae" / "themes"


def read_deco_id(aurorae_dir: Path) -> str | None:
    desktop = aurorae_dir / "metadata.desktop"
    if not desktop.is_file():
        return None
    for line in desktop.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("X-KDE-PluginInfo-Name="):
            return line.split("=", 1)[1].strip() or None
    # Fallback: directory name under themes/<slug>/aurorae → quickxp-<slug>
    return None


def which(name: str) -> str | None:
    return shutil.which(name)


def run_cmd(argv: list[str]) -> tuple[bool, str]:
    try:
        proc = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError as exc:
        return False, str(exc)
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        return False, detail or f"exit {proc.returncode}"
    return True, (proc.stdout or "").strip()


def install_package(theme_root: Path, dest_root: Path | None = None) -> dict:
    aurorae_src = theme_root / "aurorae"
    result: dict = {
        "ok": False,
        "skipped": False,
        "id": None,
        "installedPath": None,
        "warnings": [],
        "errors": [],
    }
    if not aurorae_src.is_dir():
        result["errors"].append(f"no aurorae/ package under {theme_root}")
        return result
    deco_id = read_deco_id(aurorae_src)
    if not deco_id:
        deco_id = f"quickxp-{theme_root.name}"
        result["warnings"].append(
            f"metadata.desktop missing plugin name; using {deco_id}"
        )
    dest_root = dest_root or aurorae_home()
    dest = dest_root / deco_id
    dest_root.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(aurorae_src, dest)
    # Aurorae expects <id>rc named after the plugin id.
    rc_matches = list(dest.glob("*rc"))
    expected_rc = dest / f"{deco_id}rc"
    if not expected_rc.is_file() and rc_matches:
        rc_matches[0].rename(expected_rc)
    result.update(
        {
            "ok": True,
            "id": deco_id,
            "installedPath": str(dest),
        }
    )
    return result


def select_decoration(deco_id: str) -> dict:
    """Point KWin at the Aurorae theme via kwriteconfig + reconfigure."""
    result: dict = {
        "ok": False,
        "skipped": False,
        "warnings": [],
        "errors": [],
        "selected": deco_id,
    }
    kwrite = which("kwriteconfig6") or which("kwriteconfig5") or which("kwriteconfig")
    if kwrite is None:
        result["skipped"] = True
        result["warnings"].append("kwriteconfig not found; not on Plasma/KWin?")
        return result

    theme_value = f"__aurorae__svg__{deco_id}"
    steps = [
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "library", "org.kde.kwin.aurorae"],
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "theme", theme_value],
        # Some Plasma versions also read the Aurorae group.
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kwin.aurorae", "--key", "theme", theme_value],
    ]
    for argv in steps:
        ok, detail = run_cmd(argv)
        if not ok:
            result["warnings"].append(f"{' '.join(argv)}: {detail}")

    reconfigure = None
    for candidate in (
        ["qdbus6", "org.kde.KWin", "/KWin", "reconfigure"],
        ["qdbus", "org.kde.KWin", "/KWin", "reconfigure"],
        ["dbus-send", "--type=method_call", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.reconfigure"],
    ):
        if which(candidate[0]):
            reconfigure = candidate
            break
    if reconfigure is None:
        result["warnings"].append("no qdbus/dbus-send; restart KWin or re-login to apply")
        result["ok"] = True
        return result

    ok, detail = run_cmd(reconfigure)
    if not ok:
        result["warnings"].append(f"reconfigure failed: {detail}")
    result["ok"] = True
    return result


def sync_theme(theme_root: Path, *, install_only: bool = False) -> dict:
    installed = install_package(theme_root)
    payload: dict = {
        "ok": installed.get("ok", False),
        "skipped": False,
        "themeRoot": str(theme_root),
        "id": installed.get("id"),
        "installedPath": installed.get("installedPath"),
        "warnings": list(installed.get("warnings") or []),
        "errors": list(installed.get("errors") or []),
        "selected": False,
    }
    if not installed.get("ok"):
        return payload
    if install_only:
        return payload
    selected = select_decoration(str(installed["id"]))
    payload["warnings"].extend(selected.get("warnings") or [])
    payload["errors"].extend(selected.get("errors") or [])
    payload["skipped"] = bool(selected.get("skipped"))
    payload["selected"] = bool(selected.get("ok")) and not selected.get("skipped")
    payload["ok"] = bool(selected.get("ok") or selected.get("skipped"))
    return payload


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--theme-root", type=Path, required=True)
    parser.add_argument(
        "--install-only",
        action="store_true",
        help="copy package without changing the active KWin decoration",
    )
    parser.add_argument(
        "--dest",
        type=Path,
        help="override Aurorae themes directory",
    )
    args = parser.parse_args(argv)
    root = args.theme_root.resolve()
    if args.dest is not None and args.install_only:
        payload = install_package(root, args.dest)
        payload["themeRoot"] = str(root)
        payload["selected"] = False
    else:
        payload = sync_theme(root, install_only=args.install_only)
    print(json.dumps(payload, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
