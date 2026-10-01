import QtQuick
import qs.QuickXP

QtObject {
  id: draft

  property string theme: "luna"
  property string themeScheme: ""
  property string generation: ""
  property var generationOverrides: GenerationPolicy.emptyOverrides()
  property int taskbarHeight: 0
  property bool groupButtons: false
  property bool iconsOnly: false
  property bool taskbarLocked: false
  property bool autoHide: false
  property bool showQuickLaunch: true
  property bool matchWindowBorders: true
  property string startProgramsSource: "xdgMenu"
  property string activeTab: "theme"

  readonly property bool dirty: {
    const o = Config.options
    return draft.theme !== o.theme
      || draft.themeScheme !== o.themeScheme
      || draft.generation !== o.generation
      || !GenerationPolicy.overridesEqual(draft.generationOverrides, o.generationOverrides)
      || draft.taskbarHeight !== o.taskbarHeight
      || draft.groupButtons !== o.groupButtons
      || draft.iconsOnly !== o.iconsOnly
      || draft.taskbarLocked !== o.taskbarLocked
      || draft.autoHide !== o.autoHide
      || draft.showQuickLaunch !== o.showQuickLaunch
      || draft.matchWindowBorders !== o.matchWindowBorders
      || draft.startProgramsSource !== o.startProgramsSource
  }

  function loadFromConfig() {
    const o = Config.options
    draft.theme = o.theme
    draft.themeScheme = o.themeScheme || ""
    draft.generation = o.generation
    draft.generationOverrides = GenerationPolicy.copyOverrides(o.generationOverrides)
    draft.taskbarHeight = o.taskbarHeight
    draft.groupButtons = o.groupButtons
    draft.iconsOnly = o.iconsOnly
    draft.taskbarLocked = o.taskbarLocked
    draft.autoHide = o.autoHide
    draft.showQuickLaunch = o.showQuickLaunch
    draft.matchWindowBorders = o.matchWindowBorders
    draft.startProgramsSource = o.startProgramsSource || "xdgMenu"
    draft.activeTab = o.lastSettingsTab || "theme"
  }

  function applyToConfig() {
    const o = Config.options
    o.theme = draft.theme
    o.themeScheme = draft.themeScheme || ""
    o.generation = draft.generation
    GenerationPolicy.applyOverridesToConfig(draft.generationOverrides)
    o.taskbarHeight = draft.taskbarHeight
    o.groupButtons = draft.groupButtons
    o.iconsOnly = draft.iconsOnly
    o.taskbarLocked = draft.taskbarLocked
    o.autoHide = draft.autoHide
    o.showQuickLaunch = draft.showQuickLaunch
    o.matchWindowBorders = draft.matchWindowBorders
    o.startProgramsSource = draft.startProgramsSource || "xdgMenu"
    o.lastSettingsTab = draft.activeTab
    Theme.name = draft.theme
    Theme.scheme = draft.themeScheme || ""
  }

  function setOverride(itemId: string, generation: string) {
    const next = GenerationPolicy.copyOverrides(draft.generationOverrides)
    next[itemId] = generation === undefined || generation === null ? "" : String(generation)
    draft.generationOverrides = next
  }
}
