#!/usr/bin/env python3
"""Session bus bridge between the KWin task script and QuickXP."""

import json
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
        bus_name = dbus.service.BusName(SERVICE, bus)
        super().__init__(bus, PATH, bus_name)
        self.bus = bus
        state_path.parent.mkdir(parents=True, exist_ok=True)
        if not state_path.exists():
            state_path.write_text("[]")

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
