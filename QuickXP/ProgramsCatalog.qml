pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "StartMenuModel.js" as StartMenuModel

// Loads Classic Start Programs tree (XDG menu or category buckets).
Singleton {
  id: root

  property int _revision: 0
  property var xdgTree: null
  property string xdgError: ""

  readonly property string source: StartMenuModel.normalizeSource(Config.options.startProgramsSource)

  readonly property var programsNode: {
    const _ = root._revision
    const __ = AppCatalog.applications
    if (root.source === "categories")
      return StartMenuModel.buildCategoryTree(AppCatalog.applications)
    if (root.xdgTree && root.xdgTree.children)
      return root.xdgTree
    // Fallback while XDG loads or if empty.
    return StartMenuModel.buildCategoryTree(AppCatalog.applications)
  }

  function refresh() {
    root._revision++
    if (root.source === "xdgMenu")
      xdgProc.running = true
  }

  function appsPayload() {
    const apps = AppCatalog.applications
    const out = []
    for (let i = 0; i < apps.length; ++i) {
      const e = apps[i]
      out.push({
        id: String(e.id || ""),
        name: String(e.name || ""),
        icon: String(e.icon || ""),
        categories: e.categories ? Array.from(e.categories) : [],
        noDisplay: !!e.noDisplay
      })
    }
    return JSON.stringify(out)
  }

  Connections {
    target: Config.options
    function onStartProgramsSourceChanged() {
      root.refresh()
    }
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      root.refresh()
    }
  }

  Process {
    id: xdgProc
    running: false
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/MenuBridge.py"),
      "xdg"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text) {
          root.xdgError = "empty menu"
          root.xdgTree = null
          root._revision++
          return
        }
        try {
          root.xdgTree = JSON.parse(text)
          root.xdgError = ""
        } catch (error) {
          console.warn("QuickXP ProgramsCatalog: bad menu JSON", error)
          root.xdgError = String(error)
          root.xdgTree = null
        }
        root._revision++
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP MenuBridge:", data.trim())
    }
  }

  Component.onCompleted: refresh()
}
