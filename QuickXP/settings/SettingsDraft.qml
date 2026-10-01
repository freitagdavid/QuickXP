import QtQuick
import qs.QuickXP

QtObject {
  id: draft

  property string theme: "luna"
  property int taskbarHeight: 0
  property bool groupButtons: false
  property bool iconsOnly: false
  property bool taskbarLocked: false
  property bool autoHide: false
  property bool showQuickLaunch: true
  property bool matchWindowBorders: true
  property string activeTab: "theme"

  readonly property bool dirty: {
    const o = Config.options
    return draft.theme !== o.theme
      || draft.taskbarHeight !== o.taskbarHeight
      || draft.groupButtons !== o.groupButtons
      || draft.iconsOnly !== o.iconsOnly
      || draft.taskbarLocked !== o.taskbarLocked
      || draft.autoHide !== o.autoHide
      || draft.showQuickLaunch !== o.showQuickLaunch
      || draft.matchWindowBorders !== o.matchWindowBorders
  }

  function loadFromConfig() {
    const o = Config.options
    draft.theme = o.theme
    draft.taskbarHeight = o.taskbarHeight
    draft.groupButtons = o.groupButtons
    draft.iconsOnly = o.iconsOnly
    draft.taskbarLocked = o.taskbarLocked
    draft.autoHide = o.autoHide
    draft.showQuickLaunch = o.showQuickLaunch
    draft.matchWindowBorders = o.matchWindowBorders
    draft.activeTab = o.lastSettingsTab || "theme"
  }

  function applyToConfig() {
    const o = Config.options
    o.theme = draft.theme
    o.taskbarHeight = draft.taskbarHeight
    o.groupButtons = draft.groupButtons
    o.iconsOnly = draft.iconsOnly
    o.taskbarLocked = draft.taskbarLocked
    o.autoHide = draft.autoHide
    o.showQuickLaunch = draft.showQuickLaunch
    o.matchWindowBorders = draft.matchWindowBorders
    o.lastSettingsTab = draft.activeTab
    Theme.name = draft.theme
  }
}
