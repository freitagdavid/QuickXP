pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property string name: "luna"
  // Empty = theme.json activeScheme (or sole/default scheme).
  property string scheme: ""

  // Prefer ThemeRegistry path (covers user-data imports); else shell builtin.
  readonly property string themeDir: {
    const entry = ThemeRegistry.themeBySlug(name)
    if (entry !== undefined && entry !== null && entry.path)
      return entry.path
    return Quickshell.shellPath("QuickXP/themes/" + name)
  }

  property var _raw: ({})

  // Drop previous theme's relative image paths as soon as the slug changes;
  // otherwise themeDir updates first and resolves e.g. whistler/luna/images/….
  onNameChanged: {
    root._raw = ({})
    root._data = root.blankDocument()
    themeFile.reload()
  }

  onSchemeChanged: root.applySchemeSelection()

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
      "menuText": "#000000"
    },
    "sizes": {
      "taskbarHeight": 30,
      "fontSize": 11
    },
    // No placeholder image paths — missing keys resolve to "" via image().
    "images": ({
    }),
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

  // Empty image map while switching — avoids resolving prior theme paths under the new themeDir.
  function blankDocument() {
    const blank = cloneDefaults()
    blank.images = {}
    return blank
  }

  function mergeDocument(overlay) {
    const merged = cloneDefaults()
    if (!isGroup(overlay))
      return merged

    for (const key in overlay) {
      const base = merged[key]
      const extra = overlay[key]
      // images: take the theme's map as authoritative (plus tiny defaults only
      // for keys the theme omits). Avoid carrying stale keys across switches.
      if (key === "images" && isGroup(extra))
        merged[key] = Object.assign({}, base, extra)
      else if (isGroup(base) && isGroup(extra))
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
      root._raw = JSON.parse(text)
      root.applySchemeSelection()
    } catch (error) {
      console.warn("QuickXP theme", root.name, "is invalid:", error)
      root._raw = ({})
      root._data = cloneDefaults()
    }
  }

  function applySchemeSelection() {
    const doc = root._raw
    if (!isGroup(doc)) {
      root._data = cloneDefaults()
      return
    }
    const schemeData = isGroup(doc.schemeData) ? doc.schemeData : null
    let want = root.scheme
    if (want === undefined || want === null)
      want = ""
    want = String(want)
    if (want === "" && doc.activeScheme)
      want = String(doc.activeScheme)
    if (want === "" && Array.isArray(doc.schemes) && doc.schemes.length)
      want = String(doc.schemes[0].id || "")

    let overlay = doc
    if (want !== "" && schemeData && isGroup(schemeData[want])) {
      overlay = Object.assign({}, doc, schemeData[want], { activeScheme: want })
    }
    root._data = mergeDocument(overlay)
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

  // XP Start flag lives in explorer resources, not .msstyles — fall back to Luna's.
  readonly property string defaultStartFlag: Quickshell.shellPath(
    "QuickXP/themes/luna/explorer_assets/explorer/images/143.png"
  )

  function image(key: string): string {
    const value = root.images[key]
    if (value === undefined || value === null || value === "") {
      if (key === "startFlagImage")
        return root.defaultStartFlag
      return ""
    }

    const path = String(value)
    if (path.startsWith("/") || path.startsWith("file:"))
      return path
    // Relative explorer/flag paths only exist on the Luna fixture tree.
    if (key === "startFlagImage" && path.indexOf("explorer_assets/") === 0)
      return root.defaultStartFlag
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
      root._data = root.blankDocument()
    }
  }

  Component.onCompleted: {
    if (themeFile.loaded)
      root.applyText(themeFile.text())
  }
}
