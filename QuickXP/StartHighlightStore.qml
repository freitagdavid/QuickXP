pragma Singleton

import QtQuick
import Quickshell
import qs.QuickXP
import "StartHighlight.js" as StartHighlight

Singleton {
  id: root

  property var newIdSet: ({})
  property int _revision: 0

  readonly property bool enabled: Config.options.startHighlightNew

  function currentAppIds() {
    const apps = AppCatalog.applications
    const ids = []
    for (let i = 0; i < apps.length; ++i) {
      const id = String(apps[i].id || "")
      if (id)
        ids.push(id)
    }
    return ids
  }

  function refresh() {
    if (!Config.ready)
      return
    if (!root.enabled) {
      root.newIdSet = {}
      root._revision++
      return
    }
    const result = StartHighlight.reconcile(
      Config.options.startSeenApps,
      root.currentAppIds(),
      Config.options.startSeenAppsSeeded
    )
    if (!Config.options.startSeenAppsSeeded || Config.options.startSeenApps !== result.seenJson) {
      Config.options.startSeenApps = result.seenJson
      Config.options.startSeenAppsSeeded = true
    }
    const set = {}
    for (let i = 0; i < result.newIds.length; ++i)
      set[result.newIds[i]] = true
    root.newIdSet = set
    root._revision++
  }

  function markSeen(entryId) {
    if (!entryId)
      return
    Config.options.startSeenApps = StartHighlight.markSeen(Config.options.startSeenApps, entryId)
    refresh()
  }

  function clearHighlights() {
    Config.options.startSeenApps = StartHighlight.toIdListJson(root.currentAppIds())
    Config.options.startSeenAppsSeeded = true
    refresh()
  }

  function decoratePrograms(node) {
    const _ = root._revision
    if (!root.enabled || !node)
      return node
    return StartHighlight.markNodeTree(node, root.newIdSet)
  }

  Connections {
    target: Config
    function onReadyChanged() {
      if (Config.ready)
        root.refresh()
    }
  }

  Connections {
    target: Config.options
    function onStartHighlightNewChanged() { root.refresh() }
    function onStartSeenAppsChanged() { root._revision++ }
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() { root.refresh() }
  }

  Component.onCompleted: {
    if (Config.ready)
      refresh()
  }
}
