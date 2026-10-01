pragma Singleton

import QtQuick
import Quickshell
import "AppCatalogFilter.js" as AppCatalogFilter

// Thin adapter over Quickshell DesktopEntries for Start / pins / search.
Singleton {
  id: root

  property int _revision: 0

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      root._revision++
    }
  }

  readonly property var applications: {
    const _ = root._revision
    return AppCatalogFilter.sortByName(
      AppCatalogFilter.filterLaunchable(DesktopEntries.applications)
    )
  }

  function byId(id: string) {
    return DesktopEntries.byId(id)
  }

  function lookup(name: string) {
    return DesktopEntries.heuristicLookup(name)
  }

  function filter(query: string): var {
    const _ = root._revision
    return AppCatalogFilter.sortByName(
      AppCatalogFilter.filterByQuery(DesktopEntries.applications, query)
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
