#!/usr/bin/env python3
"""Session bus bridge between the KWin task script and QuickXP."""

import json
import subprocess
import sys
from pathlib import Path

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

SERVICE = "org.quickxp.Tasks"
PATH = "/org/quickxp/Tasks"
IFACE = "org.quickxp.Tasks"


class Tasks(dbus.service.Object):
    def __init__(self, bus, state_path, script_path):
        self.state_path = state_path
        self.script_path = script_path
        self.commands = []
        self.preview_seq = 0
        bus_name = dbus.service.BusName(SERVICE, bus)
        super().__init__(bus, PATH, bus_name)
        self.bus = bus
        state_path.parent.mkdir(parents=True, exist_ok=True)
        if not state_path.exists():
            state_path.write_text("[]")
        self.ensure_preview_desktop()

    @dbus.service.method(IFACE, in_signature="s", out_signature="")
    def SetWindows(self, payload):
        text = str(payload)
        if not text:
            text = "[]"
        self.state_path.write_text(text)

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
        helper = Path(__file__).resolve().parent / "preview" / "quickxp-preview"
        window_id = str(window_id).strip()
        if not helper.is_file() or not window_id:
            return ""
        self.preview_seq += 1
        out = self.state_path.parent / f"quickxp-preview-{self.preview_seq}.png"
        for old in self.state_path.parent.glob("quickxp-preview-*.png"):
            if old != out:
                old.unlink(missing_ok=True)
        try:
            result = subprocess.run(
                [str(helper), window_id, str(out)],
                check=False,
                timeout=8,
                capture_output=True,
                text=True,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            print("quickxp tasks: preview failed:", error, file=sys.stderr)
            return ""
        if result.returncode != 0 or not out.is_file() or out.stat().st_size == 0:
            if result.stderr:
                print("quickxp tasks: preview:", result.stderr.strip(), file=sys.stderr)
            return ""
        return str(out)

    def ensure_preview_desktop(self):
        # KWin only allows ScreenShot2 for executables named by a desktop file.
        helper = Path(__file__).resolve().parent / "preview" / "quickxp-preview"
        if not helper.is_file():
            return
        desktop = Path.home() / ".local/share/applications/org.quickxp.preview.desktop"
        text = (
            "[Desktop Entry]\n"
            "Type=Application\n"
            "Name=QuickXP Preview\n"
            f"Exec={helper}\n"
            "NoDisplay=true\n"
            "X-KDE-DBUS-Restricted-Interfaces=org.kde.KWin.ScreenShot2\n"
        )
        desktop.parent.mkdir(parents=True, exist_ok=True)
        if desktop.is_file() and desktop.read_text() == text:
            return
        desktop.write_text(text)
        subprocess.run(["kbuildsycoca6", "--noincremental"], check=False, timeout=60)

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
