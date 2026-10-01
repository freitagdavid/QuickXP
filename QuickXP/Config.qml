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
