pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "StartMenuModel.js" as StartMenuModel

// Loads Classic Start Programs tree (XDG menu or category buckets).
// Tree rebuild / MenuBridge forks are deferred until Start opens (ensureReady).
Singleton {
  id: root

  property int _revision: 0
  property var xdgTree: null
  property string xdgError: ""
  property var _cachedNode: null
  property bool _dirty: true
  property int _openRefs: 0

  readonly property string source: StartMenuModel.normalizeSource(Config.options.startProgramsSource)

  readonly property bool eager: root._openRefs > 0

  readonly property var programsNode: {
    const _ = root._revision
    if (root._cachedNode && root._cachedNode.kind === "folder")
      return root._cachedNode
    return {
      kind: "folder",
      id: "programs",
      label: "Programs",
      children: []
    }
  }

  function markDirty() {
    root._dirty = true
    dirtyDebounce.restart()
  }

  function beginOpen() {
    root._openRefs++
    root.ensureReady()
  }

  function endOpen() {
    root._openRefs = Math.max(0, root._openRefs - 1)
  }

  function ensureReady() {
    if (root._dirty)
      root.rebuildNow()
  }

  function rebuildNow() {
    if (root.source === "categories") {
      root._cachedNode = StartMenuModel.buildCategoryTree(AppCatalog.applications)
      root._dirty = false
      root._revision++
      return
    }
    // xdgMenu: show last good tree (or category fallback) and refresh via MenuBridge.
    if (root.xdgTree && root.xdgTree.children)
      root._cachedNode = root.xdgTree
    else
      root._cachedNode = StartMenuModel.buildCategoryTree(AppCatalog.applications)
    root._revision++
    xdgProc.running = false
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

  Timer {
    id: dirtyDebounce
    interval: 150
    onTriggered: {
      // While Start is closed, stay dirty — no tree rebuild / MenuBridge storm.
      if (!root.eager)
        return
      root.rebuildNow()
    }
  }

  Connections {
    target: Config.options
    function onStartProgramsSourceChanged() {
      root.markDirty()
      if (root.eager)
        root.ensureReady()
    }
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      root.markDirty()
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
          if (root.source === "xdgMenu") {
            root._cachedNode = StartMenuModel.buildCategoryTree(AppCatalog.applications)
            root._dirty = false
            root._revision++
          }
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
        if (root.source === "xdgMenu") {
          if (root.xdgTree && root.xdgTree.children)
            root._cachedNode = root.xdgTree
          else
            root._cachedNode = StartMenuModel.buildCategoryTree(AppCatalog.applications)
          root._dirty = false
          root._revision++
        }
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP MenuBridge:", data.trim())
    }
  }

  Component.onCompleted: root.markDirty()
}
