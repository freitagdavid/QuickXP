pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property string name: "luna"

  readonly property string themeDir: Quickshell.shellPath("QuickXP/themes/" + name)

  readonly property var defaults: ({
    "colors": {
      "desktop": "#3A6EA5",
      "taskbar": "#245EDC",
      "taskbarText": "#FFFFFF",
      "window": "#ECE9D8",
      "windowText": "#000000",
      "titleActive": "#0054E3",
      "titleActiveText": "#FFFFFF",
      "titleInactive": "#7A96DF",
      "titleInactiveText": "#D8E4F8",
      "button": "#ECE9D8",
      "buttonText": "#000000",
      "highlight": "#316AC5",
      "highlightText": "#FFFFFF",
      "border": "#003C74",
      "menu": "#FFFFFF",
      "menuText": "#000000",
      "taskbarImage": "taskbar.png"
    },
    "sizes": {
      "taskbarHeight": 30,
      "fontSize": 11
    },
    "images": {
      "wallpaper": "wallpaper.png",
      "taskbarImage": "taskbar.png"
    },
    "fonts": {
      "ui": "Tahoma"
    }
  })

  property var _data: cloneDefaults()
  readonly property var data: _data
  readonly property var colors: data.colors || ({})
  readonly property var sizes: data.sizes || ({})
  readonly property var images: data.images || ({})
  // Theme-declared shell generation (xp | vista | win7 | classic). Consumers should
  // prefer GenerationPolicy.shell / GenerationPolicy.forItem over reading this alone.
  readonly property string generation: {
    const value = data.generation
    if (value === undefined || value === null || value === "")
      return "xp"
    return String(value).toLowerCase()
  }

  function cloneDefaults() {
    const source = root.defaults
    const copy = {}
    for (const key in source) {
      const value = source[key]
      copy[key] = isGroup(value) ? Object.assign({}, value) : value
    }
    return copy
  }

  function mergeDocument(overlay) {
    const merged = cloneDefaults()
    if (!isGroup(overlay))
      return merged

    for (const key in overlay) {
      const base = merged[key]
      const extra = overlay[key]
      if (isGroup(base) && isGroup(extra))
        merged[key] = Object.assign({}, base, extra)
      else
        merged[key] = extra
    }
    return merged
  }

  function isGroup(value): bool {
    return value !== null && typeof value === "object" && !Array.isArray(value)
  }

  function applyText(text: string) {
    try {
      root._data = mergeDocument(JSON.parse(text))
    } catch (error) {
      console.warn("QuickXP theme", root.name, "is invalid:", error)
      root._data = cloneDefaults()
    }
  }

  function color(key: string, fallback): color {
    const value = root.colors[key]
    if (value === undefined || value === null || value === "")
      return fallback === undefined ? "transparent" : fallback
    return value
  }

  function size(key: string, fallback): real {
    const value = root.sizes[key]
    if (value === undefined || value === null || value === "")
      return fallback === undefined ? 0 : fallback
    return value
  }

  function image(key: string): string {
    const value = root.images[key]
    if (value === undefined || value === null || value === "")
      return ""

    const path = String(value)
    if (path.startsWith("/") || path.startsWith("file:"))
      return path
    return root.themeDir + "/" + path
  }

  function value(group: string, key: string, fallback) {
    const section = root.data[group]
    if (!isGroup(section) || section[key] === undefined || section[key] === null)
      return fallback
    return section[key]
  }

  FileView {
    id: themeFile

    watchChanges: true
    printErrors: false
    blockLoading: true
    path: root.themeDir + "/theme.json"

    onFileChanged: reload()
    onLoaded: root.applyText(text())
    onLoadFailed: function(error) {
      console.warn("QuickXP theme", root.name, "failed to load:", FileViewError.toString(error))
      root._data = root.cloneDefaults()
    }
  }

  Component.onCompleted: {
    if (themeFile.loaded)
      root.applyText(themeFile.text())
  }
}
