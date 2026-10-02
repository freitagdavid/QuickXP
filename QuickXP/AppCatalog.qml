pragma Singleton

import QtQuick
import Quickshell
import "AppCatalogFilter.js" as AppCatalogFilter

// Thin adapter over Quickshell DesktopEntries for Start / pins / search.
// Launchable apps are materialized to plain records in QML — DesktopEntry
// properties are not reliably readable inside .pragma library helpers.
Singleton {
  id: root

  property int _revision: 0
  property var _lookupCache: ({})

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      root._revision++
      root._lookupCache = ({})
    }
  }

  function _categoriesOf(entry): var {
    if (!entry || entry.categories === undefined || entry.categories === null)
      return []
    try {
      return Array.from(entry.categories)
    } catch (error) {
      return []
    }
  }

  function _recordOf(entry): var {
    if (entry === undefined || entry === null)
      return null
    if (entry.noDisplay === true)
      return null
    const name = entry.name
    if (name === undefined || name === null || String(name).trim() === "")
      return null
    const id = String(entry.id || "").trim()
    if (!id)
      return null
    return {
      id: id,
      name: String(name),
      genericName: (entry.genericName !== undefined && entry.genericName !== null)
        ? String(entry.genericName) : "",
      icon: (entry.icon !== undefined && entry.icon !== null) ? String(entry.icon) : "",
      categories: root._categoriesOf(entry),
      noDisplay: false
    }
  }

  readonly property var applications: {
    const _ = root._revision
    // ObjectModel: use .values (same as Tray / TaskList). Indexing the model
    // directly / assuming ListModel.get() yields empty or stale entries.
    const src = DesktopEntries.applications
    const list = src && src.values !== undefined ? src.values : src
    const out = []
    if (!list)
      return out
    const count = list.length !== undefined ? list.length
      : (list.count !== undefined ? list.count : 0)
    for (let i = 0; i < count; ++i) {
      const entry = list.get !== undefined ? list.get(i) : list[i]
      const rec = root._recordOf(entry)
      if (rec)
        out.push(rec)
    }
    return AppCatalogFilter.sortByName(out)
  }

  function byId(id: string): var {
    return DesktopEntries.byId(id)
  }

  function lookup(name: string): var {
    return DesktopEntries.heuristicLookup(name)
  }

  // Cached appId → { name, icon } for taskband / menus (avoids repeated heuristicLookup).
  function resolveApp(appId: string): var {
    const key = String(appId || "").trim()
    if (!key)
      return { name: "", icon: "" }
    const hit = root._lookupCache[key]
    if (hit !== undefined && hit !== null)
      return hit
    const entry = DesktopEntries.heuristicLookup(key)
    const rec = {
      name: (entry !== null && entry !== undefined && entry.name)
        ? String(entry.name) : "",
      icon: (entry !== null && entry !== undefined && entry.icon)
        ? String(entry.icon) : ""
    }
    root._lookupCache[key] = rec
    return rec
  }

  function filter(query: string): var {
    const _ = root._revision
    return AppCatalogFilter.sortByName(
      AppCatalogFilter.filterByQuery(root.applications, query)
    )
  }

  function iconSource(entry): string {
    if (entry === undefined || entry === null)
      return ""
    const icon = entry.icon
    if (icon === undefined || icon === null || String(icon).trim() === "")
      return ""
    const text = String(icon)
    if (text.startsWith("file:") || text.startsWith("image:"))
      return text
    if (text.startsWith("/"))
      return "file://" + text
    return "image://icon/" + text
  }

  function launch(entry): bool {
    if (entry === undefined || entry === null)
      return false
    try {
      if (typeof entry.execute === "function") {
        entry.execute()
        return true
      }
    } catch (error) {
      console.warn("QuickXP AppCatalog: execute failed:", error)
    }
    const command = entry.command
    if (command !== undefined && command !== null && command.length > 0) {
      Quickshell.execDetached(command)
      return true
    }
    return false
  }
}
