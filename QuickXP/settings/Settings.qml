pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP

Singleton {
  id: root

  readonly property alias window: settingsWindow
  property bool _opened: false

  function open(tab) {
    ThemeRegistry.refresh()
    settingsWindow.loadDraft()
    if (tab !== undefined && tab !== null && String(tab) !== "")
      settingsWindow.selectTab(String(tab))
    else
      settingsWindow.selectTab(Config.options.lastSettingsTab || "theme")
    settingsWindow.visible = true
    root._opened = true
  }

  function close() {
    settingsWindow.visible = false
    root._opened = false
  }

  IpcHandler {
    target: "quickxp"
    function openSettings(tab: string): void {
      root.open(tab)
    }
    function closeSettings(): void {
      root.close()
    }
  }

  SettingsWindow {
    id: settingsWindow
  }
}
