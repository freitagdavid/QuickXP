pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Recent documents + GTK bookmarks for Classic Start Documents / Favorites.
Singleton {
  id: root

  property var recentItems: []
  property var favoriteItems: []
  property int _revision: 0

  function refresh() {
    recentProc.running = true
    favProc.running = true
  }

  function clearRecent() {
    clearProc.running = true
  }

  Process {
    id: recentProc
    running: false
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/RecentBridge.py"),
      "recent",
      "--limit", "15"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.recentItems = JSON.parse(this.text.trim() || "[]")
        } catch (error) {
          console.warn("QuickXP RecentCatalog: bad recent JSON", error)
          root.recentItems = []
        }
        root._revision++
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP RecentBridge:", data.trim())
    }
  }

  Process {
    id: favProc
    running: false
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/RecentBridge.py"),
      "favorites"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.favoriteItems = JSON.parse(this.text.trim() || "[]")
        } catch (error) {
          console.warn("QuickXP RecentCatalog: bad favorites JSON", error)
          root.favoriteItems = []
        }
        root._revision++
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP RecentBridge:", data.trim())
    }
  }

  Process {
    id: clearProc
    running: false
    command: [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/RecentBridge.py"),
      "clear-recent"
    ]
    stdout: StdioCollector {
      onStreamFinished: root.refresh()
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP RecentBridge:", data.trim())
    }
  }

  Component.onCompleted: refresh()
}
