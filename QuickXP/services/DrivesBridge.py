#!/usr/bin/env python3
"""Removable drives via lsblk + udisksctl (Epic C).

Pure helpers are unit-tested; main() is the Process loop for QML.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from typing import Any


def parse_lsblk_json(raw: str) -> list[dict[str, Any]]:
    """Return removable mountable volumes from `lsblk -J` JSON text."""
    try:
        data = json.loads(raw or "{}")
    except json.JSONDecodeError:
        return []
    devices = data.get("blockdevices")
    if not isinstance(devices, list):
        return []
    out: list[dict[str, Any]] = []

    def walk(nodes: list, parent_rm: bool = False) -> None:
        for node in nodes:
            if not isinstance(node, dict):
                continue
            rm = bool(node.get("rm")) or parent_rm
            hotplug = bool(node.get("hotplug"))
            ntype = str(node.get("type") or "")
            name = str(node.get("name") or "")
            path = str(node.get("path") or (("/dev/" + name) if name else ""))
            mount = node.get("mountpoint")
            label = str(node.get("label") or node.get("partlabel") or name)
            children = node.get("children")
            if isinstance(children, list) and children:
                walk(children, rm or hotplug)
                continue
            if ntype not in ("part", "disk", "rom"):
                continue
            if not (rm or hotplug):
                continue
            if ntype == "disk" and isinstance(children, list) and children:
                continue
            out.append(
                {
                    "id": path or name,
                    "name": name,
                    "path": path,
                    "label": label or name,
                    "mountpoint": mount if isinstance(mount, str) else "",
                    "removable": True,
                }
            )

    walk(devices)
    return out


def list_drives_from_lsblk(text: str) -> list[dict[str, Any]]:
    return parse_lsblk_json(text)


def open_command(mountpoint: str) -> list[str] | None:
    mp = str(mountpoint or "").strip()
    if not mp:
        return None
    xdg = shutil.which("xdg-open")
    if not xdg:
        return None
    return [xdg, mp]


def eject_commands(path: str) -> list[list[str]]:
    """Return argv lists to unmount then power-off a device path."""
    dev = str(path or "").strip()
    if not dev:
        return []
    udisks = shutil.which("udisksctl")
    if not udisks:
        return []
    return [
        [udisks, "unmount", "-b", dev],
        [udisks, "power-off", "-b", dev],
    ]


def run_lsblk() -> str:
    lsblk = shutil.which("lsblk")
    if not lsblk:
        return "{}"
    try:
        proc = subprocess.run(
            [lsblk, "-J", "-o", "NAME,PATH,LABEL,PARTLABEL,MOUNTPOINT,RM,HOTPLUG,TYPE"],
            check=False,
            capture_output=True,
            text=True,
        )
        return proc.stdout or "{}"
    except OSError:
        return "{}"


def handle_line(line: str) -> str:
    text = str(line or "").strip()
    if not text or text.startswith("#"):
        return ""
    parts = text.split(maxsplit=1)
    op = parts[0].upper()
    arg = parts[1] if len(parts) > 1 else ""
    if op == "LIST":
        drives = list_drives_from_lsblk(run_lsblk())
        return "DRIVES " + json.dumps(drives)
    if op == "OPEN":
        cmd = open_command(arg)
        if not cmd:
            return "ERR open"
        subprocess.Popen(cmd, start_new_session=True)
        return "OK open"
    if op == "EJECT":
        for cmd in eject_commands(arg):
            subprocess.run(cmd, check=False, capture_output=True)
        return "OK eject"
    return "ERR unknown"


def main() -> int:
    for raw in sys.stdin:
        reply = handle_line(raw.rstrip("\n"))
        if reply:
            print(reply, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
