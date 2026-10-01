#!/usr/bin/env python3
"""Session bus bridge between the KWin task script and QuickXP."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SERVICE = "org.quickxp.Tasks"
PATH = "/org/quickxp/Tasks"
IFACE = "org.quickxp.Tasks"
# Stable install path so KWin ScreenShot2 auth survives repo moves.
INSTALLED_HELPER = Path.home() / ".local" / "libexec" / "quickxp-preview"

# Re-capture in the background when a cached peek is older than this.
CACHE_REFRESH_SECS = 2.0
# Skip warm refresh when the peek is newer than this.
WARM_MAX_AGE_SECS = 30.0


def safe_window_token(window_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", str(window_id).strip()) or "unknown"


class Tasks(dbus.service.Object):
    def __init__(self, bus, state_path, script_path):
        self.state_path = state_path
        self.script_path = script_path
        self.commands = []
        self._refreshing: set[str] = set()
        self._refresh_lock = threading.Lock()
        bus_name = dbus.service.BusName(SERVICE, bus)
        super().__init__(bus, PATH, bus_name)
        self.bus = bus
        state_path.parent.mkdir(parents=True, exist_ok=True)
        if not state_path.exists():
            self._atomic_write(state_path, "[]")
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
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_name(path.name + ".tmp")
        tmp.write_text(text)
        tmp.replace(path)

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

    @dbus.service.method(IFACE, in_signature="s", out_signature="")
    def SetWindows(self, payload):
        text = str(payload)
        if not text:
            text = "[]"
        self._atomic_write(self.state_path, text)
        try:
            rows = json.loads(text)
        except json.JSONDecodeError:
            rows = []
        if isinstance(rows, list):
            # Defer warm so the KWin script is not blocked on screenshot work.
            GLib.idle_add(lambda: self._prune_and_warm(rows) or False)

    @dbus.service.method(IFACE, in_signature="", out_signature="s")
    def TakeCommands(self):
        payload = json.dumps(self.commands)
        self.commands = []
        return payload

    @dbus.service.method(IFACE, in_signature="ss", out_signature="")
    def Command(self, window_id, action):
        self.commands.append({"id": str(window_id), "action": str(action)})

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


def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} STATE_FILE SCRIPT_FILE", file=sys.stderr)
        return 1

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    state_path = Path(sys.argv[1])
    tasks = Tasks(bus, state_path, Path(sys.argv[2]))
    GLib.idle_add(tasks.load_script)
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
