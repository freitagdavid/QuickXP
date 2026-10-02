pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property alias options: adapter
  property bool ready: false

  function applyTheme() {
    if (adapter.theme !== "")
      Theme.name = adapter.theme
    Theme.scheme = adapter.themeScheme || ""
  }

  Process {
    id: ensureConfigDir
    running: true
    command: ["mkdir", "-p", Quickshell.dataDir]
  }

  FileView {
    id: configFile

    path: Quickshell.dataPath("config.json")
    watchChanges: true
    blockLoading: true
    printErrors: false

    onFileChanged: reloadTimer.restart()
    onAdapterUpdated: writeTimer.restart()
    onLoaded: {
      root.ready = true
      root.applyTheme()
    }
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound)
        writeAdapter()
      root.ready = true
      root.applyTheme()
    }

    JsonAdapter {
      id: adapter

      property string theme: "luna"
      // Color/size scheme id within the theme (NORMALBLUE, …). Empty = theme default.
      property string themeScheme: ""
      // Empty = follow Theme.generation. Else classic | xp | vista | win7.
      property string generation: ""
      property int taskbarHeight: 0
      property bool groupButtons: false
      property bool iconsOnly: false
      property bool taskbarLocked: false
      property bool autoHide: false
      property bool showQuickLaunch: true
      property bool matchWindowBorders: true
      property string lastSettingsTab: "theme"
      // Classic Start Programs tree: xdgMenu | categories
      property string startProgramsSource: "xdgMenu"
      // Highlight newly installed apps in Classic Start Programs.
      property bool startHighlightNew: true
      // JSON string array of desktop ids already seen (seeded on first use).
      property string startSeenApps: "[]"
      property bool startSeenAppsSeeded: false
      // Hide rarely used Classic Programs entries until ">>" expand.
      property bool startPersonalizedMenus: false
      property int startPersonalizedThreshold: 1
      // JSON object map desktopId -> launch count
      property string startAppUsage: "{}"
      // Debugging: open Start on load and skip hover/grab dismiss.
      property bool debugKeepStartMenuOpen: false
      // XP Start pinned apps (JSON string array of desktop ids).
      property string startPinnedApps: "[]"
      property bool startPinnedAppsSeeded: false
      // XP Start MFU list: usage scores + exclusions + visible count.
      property string startMfuScores: "{}"
      property string startMfuExcluded: "[]"
      property int startMfuCount: 6
      // XP Start right-column place visibility: link | menu | hidden
      property string startPlaceDocuments: "link"
      property string startPlaceRecentDocuments: "menu"
      property string startPlacePictures: "link"
      property string startPlaceMusic: "link"
      property string startPlaceComputer: "link"
      property string startPlaceNetwork: "link"
      property string startPlaceControlPanel: "link"
      property string startPlaceConnectTo: "link"
      property string startPlacePrinters: "link"
      property string startPlaceAdminTools: "menu"
      property string startPlaceHelp: "link"
      property string startPlaceSearch: "link"
      property string startPlaceRun: "link"

      // Per-feature generation overrides. Empty string = use shell generation.
      property JsonObject generationOverrides: JsonObject {
        property string startMenu: ""
        property string startSearch: ""
        property string quickLaunch: ""
        property string taskbarGrouping: ""
        property string showDesktop: ""
        property string livePeeks: ""
        property string notificationRetention: ""
        property string winTab: ""
        property string clockFlyout: ""
        property string altTabOverview: ""
      }
    }
  }

  Timer {
    id: reloadTimer
    interval: 50
    onTriggered: configFile.reload()
  }

  Timer {
    id: writeTimer
    interval: 50
    onTriggered: configFile.writeAdapter()
  }

  Component.onCompleted: {
    if (configFile.loaded) {
      root.ready = true
      root.applyTheme()
    }
  }
}
