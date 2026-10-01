pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var themes: []
  readonly property string themesDir: Quickshell.shellPath("QuickXP/themes")
  readonly property string indexPath: Quickshell.dataPath("themes-index.json")

  function refresh() {
    refreshTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: 50
    onTriggered: {
      if (scanner.running)
        scanner.running = false
      scanner.running = true
    }
  }

  function themeBySlug(slug: string): var {
    const list = root.themes
    for (let i = 0; i < list.length; ++i) {
      if (list[i].slug === slug)
        return list[i]
    }
    return undefined
  }

  function applyScan(text: string) {
    const trimmed = String(text).trim()
    if (trimmed === "")
      return
    try {
      const parsed = JSON.parse(trimmed)
      root.themes = Array.isArray(parsed) ? parsed : []
    } catch (error) {
      console.warn("QuickXP ThemeRegistry: invalid index:", error)
    }
  }

  Process {
    id: scanner

    running: true
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/list_themes.py"),
      root.themesDir,
      root.indexPath
    ]

    stderr: SplitParser {
      onRead: data => console.warn("QuickXP ThemeRegistry:", data.trim())
    }

    onExited: function(exitCode, _exitStatus) {
      // 15/143 = terminated when refresh restarts an in-flight scan
      if (exitCode === 0)
        indexFile.reload()
      else if (exitCode !== 15 && exitCode !== 143)
        console.warn("QuickXP ThemeRegistry: scan exited with", exitCode)
    }
  }

  FileView {
    id: indexFile

    path: root.indexPath
    watchChanges: true
    printErrors: false
    blockLoading: false

    onFileChanged: reload()
    onLoaded: root.applyScan(text())
  }

  Component.onCompleted: refresh()
}
