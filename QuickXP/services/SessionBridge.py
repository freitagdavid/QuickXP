#!/usr/bin/env python3
"""Session power actions for Classic Start (stubs until Epic 7 dialogs).

CLI:
  SessionBridge.py can <action>
  SessionBridge.py run <action>          # executes
  SessionBridge.py command <action>      # print argv JSON, no execute

Actions: logoff | poweroff | reboot | suspend
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from typing import Any


ACTIONS = ("logoff", "poweroff", "reboot", "suspend")


def which(name: str) -> str | None:
    return shutil.which(name)


def command_for(action: str) -> list[str] | None:
    act = (action or "").strip().lower()
    if act not in ACTIONS:
        return None

    if act == "logoff":
        loginctl = which("loginctl")
        if not loginctl:
            return None
        session = (os.environ.get("XDG_SESSION_ID") or "").strip()
        if session:
            return [loginctl, "terminate-session", session]
        user = (os.environ.get("USER") or os.environ.get("LOGNAME") or "").strip()
        if user:
            return [loginctl, "terminate-user", user]
        return None

    systemctl = which("systemctl")
    if not systemctl:
        return None
    if act == "poweroff":
        return [systemctl, "poweroff"]
    if act == "reboot":
        return [systemctl, "reboot"]
    if act == "suspend":
        return [systemctl, "suspend"]
    return None


def can(action: str) -> bool:
    return command_for(action) is not None


def run(action: str) -> dict[str, Any]:
    cmd = command_for(action)
    if cmd is None:
        return {"ok": False, "error": f"unsupported or unavailable: {action}"}
    try:
        subprocess.Popen(cmd)  # noqa: S603 — fixed argv from allowlist
    except OSError as error:
        return {"ok": False, "error": str(error), "command": cmd}
    return {"ok": True, "command": cmd}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="QuickXP session actions")
    parser.add_argument("mode", choices=("can", "run", "command"))
    parser.add_argument("action", choices=ACTIONS)
    args = parser.parse_args(argv)

    if args.mode == "can":
        json.dump({"action": args.action, "can": can(args.action)}, sys.stdout)
        sys.stdout.write("\n")
        return 0 if can(args.action) else 1

    if args.mode == "command":
        cmd = command_for(args.action)
        json.dump({"action": args.action, "command": cmd}, sys.stdout)
        sys.stdout.write("\n")
        return 0 if cmd else 1

    result = run(args.action)
    json.dump(result, sys.stdout)
    sys.stdout.write("\n")
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
