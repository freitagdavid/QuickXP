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

GLASS_GENERATIONS = {"vista", "win7"}


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


def theme_wants_glass(theme_root: Path) -> bool:
    """Vista/7 themes frost the shell; XP and Classic stay solid."""
    path = theme_root / "theme.json"
    if not path.is_file():
        return False
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return False
    generation = str(doc.get("generation") or "").strip().lower()
    return generation in GLASS_GENERATIONS


def kwin_glass_argv(kwrite: str, enabled: bool) -> list[list[str]]:
    flag = "true" if enabled else "false"
    return [
        [kwrite, "--file", "kwinrc", "--group", "Plugins", "--key", "blurEnabled", flag],
        [kwrite, "--file", "kwinrc", "--group", "Plugins", "--key", "contrastEnabled", flag],
    ]


def kwin_decoration_home() -> Path:
    xdg = os.environ.get("XDG_DATA_HOME")
    base = Path(xdg) if xdg else Path.home() / ".local" / "share"
    return base / "kwin" / "decorations"


def read_kdecoration_id(package: Path) -> str | None:
    meta_path = package / "metadata.json"
    if not meta_path.is_file():
        return None
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    plugin = meta.get("KPlugin") if isinstance(meta, dict) else None
    if isinstance(plugin, dict):
        ident = str(plugin.get("Id") or "").strip()
        return ident or None
    return None


def install_kdecoration(theme_root: Path, dest_root: Path | None = None) -> dict:
    src = theme_root / "kdecoration"
    result: dict = {
        "ok": False,
        "skipped": False,
        "id": None,
        "installedPath": None,
        "warnings": [],
        "errors": [],
    }
    if not src.is_dir():
        result["skipped"] = True
        result["warnings"].append(f"no kdecoration/ package under {theme_root}")
        return result
    deco_id = read_kdecoration_id(src) or f"kwin4_decoration_qml_quickxp_{theme_root.name}"
    dest_root = dest_root or kwin_decoration_home()
    dest = dest_root / deco_id
    dest_root.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest)
    result.update({"ok": True, "id": deco_id, "installedPath": str(dest)})
    return result


def preferred_decoration(theme_root: Path) -> dict:
    """Vista/7 use the QML package when it exists. XP and Classic stay on Aurorae."""
    aurorae_id = None
    aurorae_dir = theme_root / "aurorae"
    if aurorae_dir.is_dir():
        aurorae_id = read_deco_id(aurorae_dir) or f"quickxp-{theme_root.name}"
    qml_id = None
    qml_dir = theme_root / "kdecoration"
    if qml_dir.is_dir():
        qml_id = read_kdecoration_id(qml_dir)
    if theme_wants_glass(theme_root) and qml_id:
        return {"id": qml_id, "qml": True, "auroraeId": aurorae_id}
    return {"id": aurorae_id, "qml": False, "auroraeId": aurorae_id}


def decoration_config_argv(kwrite: str, deco_id: str, *, qml: bool) -> list[list[str]]:
    theme_value = deco_id if qml else f"__aurorae__svg__{deco_id}"
    return [
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "library", "org.kde.kwin.aurorae"],
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kdecoration2", "--key", "theme", theme_value],
        [kwrite, "--file", "kwinrc", "--group", "org.kde.kwin.aurorae", "--key", "theme", theme_value],
    ]


def select_decoration(deco_id: str, *, glass: bool | None = None, qml: bool = False) -> dict:
    """Point KWin at an Aurorae SVG theme or a QuickXP QML decoration."""
    result: dict = {
        "ok": False,
        "skipped": False,
        "warnings": [],
        "errors": [],
        "selected": deco_id,
        "qml": qml,
    }
    kwrite = which("kwriteconfig6") or which("kwriteconfig5") or which("kwriteconfig")
    if kwrite is None:
        result["skipped"] = True
        result["warnings"].append("kwriteconfig not found; not on Plasma/KWin?")
        return result

    steps = decoration_config_argv(kwrite, deco_id, qml=qml)
    for argv in steps:
        ok, detail = run_cmd(argv)
        if not ok:
            result["warnings"].append(f"{' '.join(argv)}: {detail}")

    if glass is not None:
        for argv in kwin_glass_argv(kwrite, glass):
            ok, detail = run_cmd(argv)
            if not ok:
                result["warnings"].append(f"{' '.join(argv)}: {detail}")
        result["glass"] = glass

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
    kdec = install_kdecoration(theme_root)
    choice = preferred_decoration(theme_root)
    chosen_id = choice.get("id")
    payload: dict = {
        "ok": bool(installed.get("ok") or kdec.get("ok")),
        "skipped": False,
        "themeRoot": str(theme_root),
        "id": chosen_id,
        "installedPath": kdec.get("installedPath") if choice.get("qml") else installed.get("installedPath"),
        "warnings": list(installed.get("warnings") or []) + list(kdec.get("warnings") or []),
        "errors": list(installed.get("errors") or []) + list(kdec.get("errors") or []),
        "selected": False,
        "qml": bool(choice.get("qml")),
    }
    if not chosen_id:
        payload["ok"] = False
        if not payload["errors"]:
            payload["errors"].append(f"no decoration package under {theme_root}")
        return payload
    if install_only:
        return payload
    selected = select_decoration(
        str(chosen_id),
        glass=theme_wants_glass(theme_root),
        qml=bool(choice.get("qml")),
    )
    payload["glass"] = selected.get("glass")
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
