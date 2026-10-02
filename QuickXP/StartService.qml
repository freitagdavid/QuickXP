pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Registry for per-screen Start popups + IPC / DBus hotkey entry points.
Singleton {
  id: root

  property var _hosts: []

  function register(host) {
    if (!host)
      return
    const list = root._hosts.slice()
    if (list.indexOf(host) >= 0)
      return
    list.push(host)
    root._hosts = list
  }

  function unregister(host) {
    if (!host)
      return
    const list = root._hosts.slice()
    const idx = list.indexOf(host)
    if (idx < 0)
      return
    list.splice(idx, 1)
    root._hosts = list
  }

  function _preferredHost() {
    const list = root._hosts
    if (!list || list.length === 0)
      return null
    for (let i = 0; i < list.length; ++i) {
      const h = list[i]
      if (h && h.visible)
        return h
    }
    // Prefer the host on the primary / first screen when possible.
    const screens = Quickshell.screens
    const primary = screens && screens.length ? screens[0] : null
    if (primary) {
      for (let j = 0; j < list.length; ++j) {
        const host = list[j]
        if (host && host.screen === primary)
          return host
      }
    }
    return list[0]
  }

  function open() {
    const host = root._preferredHost()
    if (!host || typeof host.open !== "function")
      return
    // Meta/hotkey: skip Wayland grab (key-release dismisses Qt::Popup) and
    // suppress leave-region close while focus settles.
    host.openedByHotkey = true
    if (typeof host.pokeSuppress === "function")
      host.pokeSuppress()
    host.open()
  }

  function close() {
    const list = root._hosts
    for (let i = 0; i < list.length; ++i) {
      const host = list[i]
      if (host && host.visible && typeof host.close === "function")
        host.close(true)
    }
  }

  function toggle() {
    const list = root._hosts
    for (let i = 0; i < list.length; ++i) {
      const host = list[i]
      if (host && host.visible) {
        if (typeof host.close === "function")
          host.close(true)
        return
      }
    }
    root.open()
  }

  IpcHandler {
    target: "start"
    function toggle(): void {
      root.toggle()
    }
    function open(): void {
      root.open()
    }
    function close(): void {
      root.close()
    }
    function hostCount(): int {
      return root._hosts ? root._hosts.length : 0
    }
    function isOpen(): bool {
      const list = root._hosts
      for (let i = 0; i < list.length; ++i) {
        if (list[i] && list[i].visible)
          return true
      }
      return false
    }
  }

  // Meta → kglobalaccel (org.quickxp.start.desktop) → DBus ToggleStart → stdout TOGGLE.
  Process {
    id: shellBridge
    running: true
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/ShellBridge.py")
    ]
    stdout: SplitParser {
      onRead: data => {
        const line = String(data).trim()
        if (line === "TOGGLE") {
          root.toggle()
          return
        }
        if (line === "OPEN") {
          root.open()
          return
        }
        if (line)
          console.log("QuickXP ShellBridge:", line)
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP ShellBridge:", data.trim())
    }
  }
}
