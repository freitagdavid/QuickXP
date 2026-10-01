import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.taskbar
import qs.QuickXP.settings

ShellRoot {
  // Keep Settings singleton alive for Settings.open() from menus.
  readonly property var settings: Settings

  Component.onCompleted: {
    if (Config.ready)
      Theme.name = Config.options.theme
  }

  Connections {
    target: Config.options
    function onThemeChanged() {
      Theme.name = Config.options.theme
    }
  }

  Variants {
    model: Quickshell.screens
    TaskBar {}
  }
}
