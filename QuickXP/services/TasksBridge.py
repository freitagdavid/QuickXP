#!/usr/bin/env python3
"""Session bus bridge between the KWin task script and QuickXP."""

from __future__ import annotations

import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

SERVICE = "org.quickxp.Tasks"
PATH = "/org/quickxp/Tasks"
IFACE = "org.quickxp.Tasks"
# Stable install path so KWin ScreenShot2 auth survives repo moves.
INSTALLED_HELPER = Path.home() / ".local" / "libexec" / "quickxp-preview"

# Re-capture in the background when a cached peek is older than this.
CACHE_REFRESH_SECS = 2.0
# Skip warm refresh when the peek is newer than this.
WARM_MAX_AGE_SECS = 30.0

try:
    import dbus
    import dbus.service
    from dbus.mainloop.glib import DBusGMainLoop
    from gi.repository import GLib

    _HAS_DBUS = True
except ImportError:  # pragma: no cover — CI/pytest without system dbus-python
    dbus = None  # type: ignore[assignment]
    dbus_service = None  # type: ignore[assignment]
    DBusGMainLoop = None  # type: ignore[assignment]
    GLib = None  # type: ignore[assignment]
    _HAS_DBUS = False


def _cmdline_is_tasks_bridge(parts: list[str]) -> bool:
    """True when argv is a python interpreter running TasksBridge.py."""
    if not parts:
        return False
    if "python" not in Path(parts[0]).name:
        return False
    return any(p.rstrip("/").endswith("TasksBridge.py") for p in parts)


def stale_bridge_pids(proc_root: Path | None = None, self_pid: int | None = None) -> list[int]:
    """PIDs of other TasksBridge.py processes (orphans after quickshell -9)."""
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
        if _cmdline_is_tasks_bridge(parts):
            found.append(pid)
    return found


def reap_stale_bridges() -> int:
    """SIGTERM/SIGKILL other TasksBridge instances so we can own the DBus name."""
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


def safe_window_token(window_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", str(window_id).strip()) or "unknown"


def normalize_windows_payload(payload) -> str:
    text = str(payload) if payload is not None else ""
    return text if text else "[]"


def apply_script_for(publish_script: Path) -> Path:
    """Helper body for one-shot apply scripts (sibling of tasks.js)."""
    return Path(publish_script).resolve().parent / "tasks-apply.js"


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


def build_apply_script_text(helper_text: str, commands: list) -> str:
    """Inline commands so KWin run() applies synchronously."""
    return (
        helper_text.rstrip()
        + "\n\nvar commands = "
        + json.dumps(commands)
        + ";\ncommands.forEach(applyCommand);\n"
    )


if _HAS_DBUS:

    class Tasks(dbus.service.Object):
        def __init__(self, bus, state_path, script_path):
            self.state_path = state_path
            self.script_path = script_path
            self.commands = []
            self._last_windows_text: str | None = None
            self._apply_scheduled = False
            self._refreshing: set[str] = set()
            self._refresh_lock = threading.Lock()
            # replace_existing: survive quickshell reloads when an old bridge still holds the name.
            bus_name = dbus.service.BusName(
                SERVICE,
                bus,
                allow_replacement=True,
                replace_existing=True,
                do_not_queue=True,
            )
            super().__init__(bus, PATH, bus_name)
            self.bus = bus
            state_path.parent.mkdir(parents=True, exist_ok=True)
            if not state_path.exists():
                atomic_write(state_path, "[]")
                self._last_windows_text = "[]"
            else:
                try:
                    self._last_windows_text = state_path.read_text()
                except OSError:
                    self._last_windows_text = None
            self._purge_legacy_previews()
            self.ensure_preview_helper()

        def built_helper(self) -> Path:
            return (Path(__file__).resolve().parent / "preview" / "quickxp-preview").resolve()

        def ensure_preview_helper(self) -> Path | None:
            # KWin authorizes ScreenShot2 by matching /proc/self/exe to a desktop
            # file's Exec= plus X-KDE-DBUS-Restricted-Interfaces. Install a copy
            # under ~/.local/libexec so reorganizing the repo does not break auth.
            built = self.built_helper()
            if not built.is_file():
                if INSTALLED_HELPER.is_file():
                    return INSTALLED_HELPER
                return None

            INSTALLED_HELPER.parent.mkdir(parents=True, exist_ok=True)
            need_copy = (
                not INSTALLED_HELPER.is_file()
                or INSTALLED_HELPER.stat().st_mtime < built.stat().st_mtime
                or INSTALLED_HELPER.stat().st_size != built.stat().st_size
            )
            if need_copy:
                try:
                    INSTALLED_HELPER.write_bytes(built.read_bytes())
                    INSTALLED_HELPER.chmod(0o755)
                except OSError as error:
                    print("quickxp tasks: install preview helper failed:", error, file=sys.stderr)
                    if not INSTALLED_HELPER.is_file():
                        return None

            desktop = Path.home() / ".local/share/applications/org.quickxp.preview.desktop"
            text = (
                "[Desktop Entry]\n"
                "Type=Application\n"
                "Name=QuickXP Preview\n"
                f"Exec={INSTALLED_HELPER}\n"
                "NoDisplay=true\n"
                "X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2\n"
            )
            desktop.parent.mkdir(parents=True, exist_ok=True)
            changed = not desktop.is_file() or desktop.read_text() != text
            if changed:
                desktop.write_text(text)

            stamp = Path.home() / ".cache" / "quickxp-preview-sycoca"
            stamp_val = f"{INSTALLED_HELPER}\n{INSTALLED_HELPER.stat().st_mtime_ns}"
            need_rebuild = changed or not stamp.is_file() or stamp.read_text() != stamp_val
            if need_rebuild:
                # Keep kbuildsycoca chatter off the Quickshell stderr WARN stream.
                subprocess.run(
                    ["kbuildsycoca6", "--noincremental"],
                    check=False,
                    timeout=60,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                stamp.parent.mkdir(parents=True, exist_ok=True)
                stamp.write_text(stamp_val)
            return INSTALLED_HELPER

        def _atomic_write(self, path: Path, text: str) -> None:
            atomic_write(path, text)

        def preview_dir(self) -> Path:
            return self.state_path.parent

        def preview_path(self, window_id: str) -> Path:
            return self.preview_dir() / f"quickxp-preview-w-{safe_window_token(window_id)}.png"

        def _purge_legacy_previews(self) -> None:
            # Older builds used incrementing quickxp-preview-N.png and deleted peers.
            for path in self.preview_dir().glob("quickxp-preview-*.png"):
                if path.name.startswith("quickxp-preview-w-"):
                    continue
                path.unlink(missing_ok=True)

        def _cache_fresh(self, path: Path, max_age: float) -> bool:
            try:
                if not path.is_file() or path.stat().st_size <= 0:
                    return False
                return (time.time() - path.stat().st_mtime) <= max_age
            except OSError:
                return False

        def _capture(self, window_id: str, out: Path) -> bool:
            helper = self.ensure_preview_helper()
            if helper is None or not helper.is_file():
                return False
            tmp = out.with_suffix(out.suffix + ".tmp")
            try:
                result = subprocess.run(
                    [str(helper), window_id, str(tmp)],
                    check=False,
                    timeout=8,
                    capture_output=True,
                    text=True,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                print("quickxp tasks: preview failed:", error, file=sys.stderr)
                tmp.unlink(missing_ok=True)
                return False
            if result.returncode != 0 or not tmp.is_file() or tmp.stat().st_size == 0:
                if result.stderr:
                    print("quickxp tasks: preview:", result.stderr.strip(), file=sys.stderr)
                tmp.unlink(missing_ok=True)
                return False
            tmp.replace(out)
            return True

        def _schedule_refresh(self, window_id: str, *, force: bool = False) -> None:
            out = self.preview_path(window_id)
            if not force and self._cache_fresh(out, WARM_MAX_AGE_SECS):
                return
            with self._refresh_lock:
                if window_id in self._refreshing:
                    return
                self._refreshing.add(window_id)

            def work() -> None:
                try:
                    self._capture(window_id, out)
                finally:
                    with self._refresh_lock:
                        self._refreshing.discard(window_id)

            threading.Thread(target=work, daemon=True, name=f"quickxp-preview-{window_id}").start()

        def _prune_and_warm(self, rows: list) -> None:
            ids: set[str] = set()
            for row in rows:
                if not isinstance(row, dict):
                    continue
                wid = str(row.get("id") or "").strip()
                if wid:
                    ids.add(wid)

            for path in self.preview_dir().glob("quickxp-preview-w-*.png"):
                token = path.name[len("quickxp-preview-w-") : -len(".png")]
                # Keep files whose token still matches a live id's safe form.
                if not any(safe_window_token(wid) == token for wid in ids):
                    path.unlink(missing_ok=True)

            for wid in ids:
                self._schedule_refresh(wid, force=False)

        def write_windows_if_changed(self, payload) -> bool:
            """Write state file when payload text changes. Returns True if written."""
            text = normalize_windows_payload(payload)
            if text == self._last_windows_text:
                return False
            self._atomic_write(self.state_path, text)
            self._last_windows_text = text
            try:
                rows = json.loads(text)
            except json.JSONDecodeError:
                rows = []
            if isinstance(rows, list):
                # Defer warm so the KWin script is not blocked on screenshot work.
                GLib.idle_add(lambda: self._prune_and_warm(rows) or False)
            return True

        @dbus.service.method(IFACE, in_signature="s", out_signature="")
        def SetWindows(self, payload):
            self.write_windows_if_changed(payload)

        @dbus.service.method(IFACE, in_signature="", out_signature="s")
        def TakeCommands(self):
            payload = json.dumps(self.commands)
            self.commands = []
            return payload

        def schedule_apply(self) -> None:
            """Coalesce rapid Command() calls into one KWin one-shot apply."""
            if self._apply_scheduled:
                return
            self._apply_scheduled = True
            GLib.idle_add(self._run_apply_script)

        def build_apply_script(self, commands: list) -> Path | None:
            """Write a one-shot script with commands inlined (no async TakeCommands)."""
            helper = apply_script_for(self.script_path)
            if not helper.is_file():
                print("quickxp tasks: apply script missing:", helper, file=sys.stderr)
                return None
            try:
                body = helper.read_text()
            except OSError as error:
                print("quickxp tasks: read apply helper failed:", error, file=sys.stderr)
                return None
            text = build_apply_script_text(body, commands)
            out = self.state_path.parent / "quickxp-tasks-apply-once.js"
            try:
                atomic_write(out, text)
            except OSError as error:
                print("quickxp tasks: write apply script failed:", error, file=sys.stderr)
                return None
            return out

        def _finish_apply_script(self, scripting, script, path: str) -> bool:
            try:
                script.stop()
            except dbus.DBusException:
                pass
            try:
                scripting.unloadScript(path)
            except dbus.DBusException:
                pass
            return False

        def _activate_via_windows_runner(self, window_id: str) -> bool:
            """Raise/focus without a KWin script (sync from this process)."""
            wid = str(window_id).strip()
            if not wid:
                return False
            # Match tasks.js: WindowsRunner ids are "0_" + internalId.
            token = wid if wid.startswith("0_") else "0_" + wid
            try:
                remote = self.bus.get_object("org.kde.KWin", "/WindowsRunner")
                runner = dbus.Interface(remote, "org.kde.krunner1")
                runner.Run(token, "")
                return True
            except dbus.DBusException as error:
                print("quickxp tasks: WindowsRunner activate failed:", error, file=sys.stderr)
                return False

        def _run_apply_script(self) -> bool:
            self._apply_scheduled = False
            if not self.commands:
                return False
            commands = self.commands
            self.commands = []

            # Activate can be done via session-bus WindowsRunner; avoids one-shot
            # script races for the common taskbar click path.
            remaining = []
            for command in commands:
                action = str(command.get("action") or "")
                wid = str(command.get("id") or "")
                if action == "activate" and self._activate_via_windows_runner(wid):
                    continue
                remaining.append(command)
            if not remaining:
                return False

            apply_path = self.build_apply_script(remaining)
            if apply_path is None:
                # Put commands back so a later kick can retry.
                self.commands = remaining + self.commands
                return False
            try:
                remote = self.bus.get_object("org.kde.KWin", "/Scripting")
                scripting = dbus.Interface(remote, "org.kde.kwin.Scripting")
                path = str(apply_path)
                resolved = str(apply_path.resolve())
                for candidate in (path, resolved) if resolved != path else (path,):
                    try:
                        if scripting.isScriptLoaded(candidate):
                            scripting.unloadScript(candidate)
                    except dbus.DBusException:
                        pass
                number = int(scripting.loadScript(path))
                script = dbus.Interface(
                    self.bus.get_object("org.kde.KWin", f"/Scripting/Script{number}"),
                    "org.kde.kwin.Script",
                )
                script.run()
                # Delay stop/unload so any remaining async callDBus in the script
                # (WindowsRunner fallback) can finish.
                GLib.timeout_add(
                    400,
                    lambda: self._finish_apply_script(scripting, script, path),
                )
            except dbus.DBusException as error:
                print("quickxp tasks: apply failed:", error, file=sys.stderr)
            return False

        @dbus.service.method(IFACE, in_signature="ss", out_signature="")
        def Command(self, window_id, action):
            self.commands.append({"id": str(window_id), "action": str(action)})
            self.schedule_apply()

        @dbus.service.method(IFACE, in_signature="s", out_signature="s")
        def Preview(self, window_id):
            window_id = str(window_id).strip()
            if not window_id:
                return ""
            out = self.preview_path(window_id)
            # Serve cache immediately; refresh in the background so hover is snappy.
            if out.is_file() and out.stat().st_size > 0:
                if not self._cache_fresh(out, CACHE_REFRESH_SECS):
                    self._schedule_refresh(window_id, force=True)
                return str(out)
            if self._capture(window_id, out):
                return str(out)
            return ""

        def load_script(self):
            remote = self.bus.get_object("org.kde.KWin", "/Scripting")
            scripting = dbus.Interface(remote, "org.kde.kwin.Scripting")
            path = str(self.script_path)
            # The config path is often a symlink of the project file. KWin treats
            # those as different scripts, so unload both before loading one.
            candidates = [path]
            resolved = str(self.script_path.resolve())
            if resolved not in candidates:
                candidates.append(resolved)
            for candidate in candidates:
                try:
                    if scripting.isScriptLoaded(candidate):
                        scripting.unloadScript(candidate)
                except dbus.DBusException as error:
                    print("quickxp tasks: unload failed:", error, file=sys.stderr)
            try:
                number = int(scripting.loadScript(path))
                script = dbus.Interface(
                    self.bus.get_object("org.kde.KWin", f"/Scripting/Script{number}"),
                    "org.kde.kwin.Script",
                )
                script.run()
            except dbus.DBusException as error:
                print("quickxp tasks: load failed:", error, file=sys.stderr)
            return False

else:  # pragma: no cover
    Tasks = None  # type: ignore[misc, assignment]


def main():
    if not _HAS_DBUS:
        print("quickxp tasks: dbus-python / PyGObject required", file=sys.stderr)
        return 1
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} STATE_FILE SCRIPT_FILE", file=sys.stderr)
        return 1

    killed = reap_stale_bridges()
    if killed:
        print(f"quickxp tasks: reaped {killed} stale TasksBridge process(es)", flush=True)

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    state_path = Path(sys.argv[1])
    tasks = Tasks(bus, state_path, Path(sys.argv[2]))
    GLib.idle_add(tasks.load_script)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
