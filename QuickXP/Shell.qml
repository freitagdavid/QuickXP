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
  // Keep app catalog bound for Start / pins / search.
  readonly property var appCatalog: AppCatalog
  // Keep Programs tree loader alive for Classic Start.
  readonly property var programsCatalog: ProgramsCatalog
  readonly property var recentCatalog: RecentCatalog
  readonly property var startHighlightStore: StartHighlightStore
  readonly property var startPersonalizeStore: StartPersonalizeStore
  // Keep dropdown exclusivity gate alive.
  readonly property var dropdownGate: DropdownGate

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
