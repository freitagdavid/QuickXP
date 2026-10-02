pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var drives: []
  property int _revision: 0

  readonly property bool hasDrives: drives.length > 0

  function refresh() {
    if (!bridge.running)
      return
    bridge.write("LIST\n")
  }

  function openMount(mountpoint) {
    if (!bridge.running || !mountpoint)
      return
    bridge.write("OPEN " + String(mountpoint) + "\n")
  }

  function eject(path) {
    if (!bridge.running || !path)
      return
    bridge.write("EJECT " + String(path) + "\n")
    Qt.callLater(root.refresh)
  }

  function onStdout(data) {
    const line = String(data).trim()
    if (!line)
      return
    if (line.startsWith("DRIVES ")) {
      try {
        const parsed = JSON.parse(line.slice(7))
        root.drives = Array.isArray(parsed) ? parsed : []
      } catch (e) {
        root.drives = []
      }
      root._revision++
      return
    }
  }

  Process {
    id: bridge
    stdinEnabled: true
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/DrivesBridge.py")
    ]
    running: true
    stdout: SplitParser {
      onRead: data => root.onStdout(data)
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP drives:", data.trim())
    }
    onStarted: root.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
