import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.taskbar
import qs.QuickXP.settings

ShellRoot {
  // Keep Settings singleton alive for Settings.open() from menus.
  readonly property var settings: Settings
  // Keep generation policy bound so Config/Theme changes resolve live.
  readonly property var generationPolicy: GenerationPolicy

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
