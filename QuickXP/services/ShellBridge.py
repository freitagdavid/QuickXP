#!/usr/bin/env python3
"""Bind Windows/Meta to QuickXP Start (Plasma 6 kglobalaccel) and signal the shell."""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

SERVICE = "org.quickxp.Shell"
PATH = "/org/quickxp/Shell"
IFACE = "org.quickxp.Shell"

DESKTOP_ID = "org.quickxp.start.desktop"
DESKTOP_NAME = "QuickXP Start Menu"
# Qt::Key_Meta — bare Windows/Meta key.
META_KEY = 16777250
# Qt::META | Qt::Key_Space — reliable non-modifier-only Start binding.
META_SPACE = 0x10000000 | 0x20  # 268435488
# plasmashell launcher Alt+F1 encoding (kept as secondary).
PLASMA_LAUNCHER_ALT_F1 = 150994992

# Keys bound to org.quickxp.start.desktop _launch.
START_SHORTCUT_KEYS = (
    [META_KEY, 0, 0, 0],
    [META_SPACE, 0, 0, 0],
)

LEGACY_META_BINDING = f"{SERVICE},{PATH},{IFACE},ToggleStart"

# Commands printed on stdout for the Quickshell Process SplitParser.
CMD_TOGGLE = "TOGGLE"
CMD_OPEN = "OPEN"


def emit(command: str) -> None:
    """Notify the parent Quickshell process (preferred path — no qs fork)."""
    print(command, flush=True)


def _cmdline_is_shell_bridge(parts: list[str]) -> bool:
    """True when argv is a python interpreter running ShellBridge.py."""
    if not parts:
        return False
    if "python" not in Path(parts[0]).name:
        return False
    return any(p.rstrip("/").endswith("ShellBridge.py") for p in parts)


def stale_bridge_pids(proc_root: Path | None = None, self_pid: int | None = None) -> list[int]:
    """PIDs of other ShellBridge.py processes (orphans after quickshell -9)."""
    root = proc_root if proc_root is not None else Path("/proc")
    me = os.getpid() if self_pid is None else self_pid
    found: list[int] = []
    try:
        entries = list(root.iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid == me:
            continue
        try:
            raw = (entry / "cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        parts = [p.decode("utf-8", "replace") for p in raw if p]
        if _cmdline_is_shell_bridge(parts):
            found.append(pid)
    return found


def reap_stale_bridges() -> int:
    """SIGTERM/SIGKILL other ShellBridge instances so we can own the DBus name."""
    pids = stale_bridge_pids()
    if not pids:
        return 0
    killed = 0
    for sig in (signal.SIGTERM, signal.SIGKILL):
        still: list[int] = []
        for pid in pids:
            try:
                os.kill(pid, sig)
                killed += 1
                still.append(pid)
            except OSError:
                pass
        if not still:
            break
        pids = still
        if sig == signal.SIGTERM:
            time.sleep(0.08)
    return killed


def qs_bin() -> str:
    for name in ("/usr/bin/qs", "/usr/bin/quickshell"):
        if Path(name).is_file():
            return name
    for name in ("qs", "quickshell"):
        path = shutil.which(name)
        if path:
            return path
    return "qs"


def qs_config_name() -> str:
    return os.environ.get("QS_CONFIG_NAME") or os.environ.get("QUICKXP_QS_CONFIG") or "default"


def call_start_ipc(verb: str) -> None:
    """Fallback when stdout is not connected to Quickshell (manual dbus calls)."""
    env = os.environ.copy()
    # Ensure qs can find the running instance when launched from a lean service env.
    if "WAYLAND_DISPLAY" not in env:
        env["WAYLAND_DISPLAY"] = "wayland-0"
    if "XDG_RUNTIME_DIR" not in env:
        env["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
    cmd = [qs_bin(), "-c", qs_config_name(), "ipc", "call", "start", verb]
    try:
        subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
            env=env,
        )
    except OSError as error:
        print(f"quickxp shell: ipc {verb} failed: {error}", file=sys.stderr)


def kreadconfig(*args: str) -> str:
    for tool in ("kreadconfig6", "kreadconfig5"):
        if shutil.which(tool):
            try:
                out = subprocess.check_output([tool, *args], text=True, stderr=subprocess.DEVNULL)
                return out.strip()
            except (OSError, subprocess.CalledProcessError):
                return ""
    return ""


def kwriteconfig(*args: str) -> bool:
    for tool in ("kwriteconfig6", "kwriteconfig5"):
        if shutil.which(tool):
            try:
                subprocess.run([tool, *args], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return True
            except OSError:
                return False
    return False


def busctl(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["busctl", "--user", *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def desktop_paths() -> tuple[Path, Path]:
    home = Path.home()
    return (
        home / ".local/share/applications" / DESKTOP_ID,
        home / ".local/share/kglobalaccel" / DESKTOP_ID,
    )


def toggle_exec_line() -> str:
    """Absolute Exec= for kglobalaccel's lean PATH."""
    for name in ("qdbus6", "qdbus"):
        path = shutil.which(name)
        if path:
            return f"Exec={path} {SERVICE} {PATH} {IFACE}.ToggleStart\n"
    gdbus = shutil.which("gdbus") or "gdbus"
    return (
        f"Exec={gdbus} call --session --dest {SERVICE} "
        f"--object-path {PATH} --method {IFACE}.ToggleStart\n"
    )


def write_desktop_files() -> None:
    # Meta → kglobalaccel → this desktop → DBus ToggleStart on our long-lived bridge.
    # Avoid `qs ipc` here: kglobalaccel launches with a lean env that often cannot
    # see the running Quickshell instance.
    text = (
        "[Desktop Entry]\n"
        "Type=Application\n"
        f"Name={DESKTOP_NAME}\n"
        "Comment=Toggle the QuickXP Start menu\n"
        f"{toggle_exec_line()}"
        "Icon=start-here\n"
        "NoDisplay=true\n"
        "StartupNotify=false\n"
        "DBusActivatable=false\n"
    )

    app, accel = desktop_paths()
    app.parent.mkdir(parents=True, exist_ok=True)
    accel.parent.mkdir(parents=True, exist_ok=True)
    for path in (app, accel):
        if not path.is_file() or path.read_text(encoding="utf-8") != text:
            path.write_text(text, encoding="utf-8")
    if shutil.which("kbuildsycoca6"):
        subprocess.run(
            ["kbuildsycoca6", "--noincremental"],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def clear_legacy_kwinrc_meta() -> None:
    current = kreadconfig("--file", "kwinrc", "--group", "ModifierOnlyShortcuts", "--key", "Meta")
    if current == LEGACY_META_BINDING:
        kwriteconfig("--file", "kwinrc", "--group", "ModifierOnlyShortcuts", "--key", "Meta", "--delete")


def shortcut_keys(component: str, action: str, friendly: str, description: str) -> str:
    result = busctl(
        "call", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
        "shortcutKeys", "as", "4", component, action, friendly, description,
    )
    return (result.stdout or "").strip()


def set_shortcut_keys(
    component: str,
    action: str,
    friendly: str,
    description: str,
    keys: list[list[int]],
    flags: int = 4,
) -> bool:
    args: list[str] = [
        "call", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
        "setShortcutKeys", "asa(ai)u",
        "4", component, action, friendly, description,
        str(len(keys)),
    ]
    for seq in keys:
        args.append(str(len(seq)))
        args.extend(str(v) for v in seq)
    args.append(str(flags))
    result = busctl(*args)
    if result.returncode != 0:
        print(
            f"quickxp shell: setShortcutKeys failed for {component}/{action}: "
            f"{(result.stderr or result.stdout).strip()}",
            file=sys.stderr,
        )
        return False
    return True


def do_register(component: str, action: str, friendly: str, description: str) -> None:
    busctl(
        "call", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
        "doRegister", "as", "4", component, action, friendly, description,
    )


def install_meta_shortcut() -> None:
    """Bind Meta and Meta+Space via kglobalaccel → .desktop Exec → DBus ToggleStart.

    Bare Meta uses Plasma 6.1+ modifier-only handling; Meta+Space is a normal
    chord and is the more reliable open path when modifier-only is flaky.
    """
    write_desktop_files()
    clear_legacy_kwinrc_meta()

    launcher_keys = shortcut_keys(
        "plasmashell", "activate application launcher", "Plasma", "Activate Application Launcher"
    )
    if str(META_KEY) in launcher_keys:
        set_shortcut_keys(
            "plasmashell",
            "activate application launcher",
            "Plasma",
            "Activate Application Launcher",
            [[PLASMA_LAUNCHER_ALT_F1, 0, 0, 0]],
        )

    # Free Meta from the old KWin script action if it still holds it.
    kwin_keys = shortcut_keys("kwin", "QuickXPStart", "KWin", "QuickXP Start Menu")
    if str(META_KEY) in kwin_keys or str(META_SPACE) in kwin_keys:
        set_shortcut_keys("kwin", "QuickXPStart", "KWin", "QuickXP Start Menu", [])

    component = DESKTOP_ID
    action = "_launch"
    friendly = "QuickXP"
    description = "Toggle Start Menu"
    do_register(component, action, friendly, description)
    current = shortcut_keys(component, action, friendly, description)
    need = [str(META_KEY), str(META_SPACE)]
    if any(k not in current for k in need):
        ok = set_shortcut_keys(
            component,
            action,
            friendly,
            description,
            [list(seq) for seq in START_SHORTCUT_KEYS],
        )
        if not ok:
            print("quickxp shell: failed to bind Meta / Meta+Space to Start", file=sys.stderr)
            return

    print("quickxp shell: Meta / Meta+Space → kglobalaccel desktop → DBus ToggleStart", flush=True)


def main() -> int:
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib

    class Shell(dbus.service.Object):
        def __init__(self, bus):
            # Replace orphan bridges from previous quickshell instances so Meta
            # ToggleStart always reaches the currently running shell.
            bus_name = dbus.service.BusName(
                SERVICE,
                bus,
                allow_replacement=True,
                replace_existing=True,
            )
            super().__init__(bus, PATH, bus_name)
            self._defer_pending = False

        def _defer(self, command: str, ipc_verb: str) -> None:
            # Coalesce duplicate Meta deliveries (press+release or double invoke).
            if self._defer_pending:
                return
            self._defer_pending = True

            # Run after Meta is fully released so the key-up is not treated as an
            # outside click that dismisses a grabbing Qt::Popup.
            def run():
                self._defer_pending = False
                if not sys.stdout.isatty():
                    emit(command)
                else:
                    call_start_ipc(ipc_verb)
                return False  # do not repeat

            GLib.timeout_add(280, run)

        @dbus.service.method(IFACE, in_signature="", out_signature="")
        def ToggleStart(self):
            self._defer(CMD_TOGGLE, "toggle")

        @dbus.service.method(IFACE, in_signature="", out_signature="")
        def OpenStart(self):
            self._defer(CMD_OPEN, "open")

        @dbus.service.method(IFACE, in_signature="", out_signature="")
        def InstallMetaShortcut(self):
            install_meta_shortcut()

    reaped = reap_stale_bridges()
    if reaped:
        print(f"quickxp shell: reaped {reaped} stale ShellBridge process(es)", flush=True)

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    Shell(bus)
    # Install off the main thread so DBus is ready before Meta can fire.
    threading.Thread(target=install_meta_shortcut, name="quickxp-meta-bind", daemon=True).start()
    loop = GLib.MainLoop()
    loop.run()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # noqa: BLE001
        print(f"quickxp shell: fatal: {error}", file=sys.stderr)
        raise
