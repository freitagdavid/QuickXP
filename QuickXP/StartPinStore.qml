pragma Singleton

import QtQuick
import Quickshell
import qs.QuickXP
import "StartPin.js" as StartPin

Singleton {
  id: root

  property int _revision: 0

  readonly property var pinIds: {
    const _ = root._revision
    const __seeded = Config.options.startPinnedAppsSeeded
    const __pins = Config.options.startPinnedApps
    const __apps = AppCatalog._revision
    return StartPin.parsePins(__pins)
  }

  readonly property var pinRows: {
    const ids = root.pinIds
    const rows = []
    for (let i = 0; i < ids.length; ++i) {
      const id = ids[i]
      const entry = AppCatalog.byId(id)
      if (!entry)
        continue
      rows.push({
        kind: "app",
        id: id,
        entryId: id,
        label: String(entry.name || entry.id || id),
        icon: String(entry.icon || ""),
        pinIndex: i
      })
    }
    return rows
  }

  function ensureSeeded() {
    if (!Config.ready)
      return
    if (Config.options.startPinnedAppsSeeded)
      return
    const defaults = StartPin.defaultPinIds(AppCatalog.applications)
    Config.options.startPinnedApps = StartPin.pinsJson(defaults)
    Config.options.startPinnedAppsSeeded = true
    root._revision++
  }

  function pin(entryId) {
    Config.options.startPinnedApps = StartPin.pin(Config.options.startPinnedApps, entryId)
    Config.options.startPinnedAppsSeeded = true
    root._revision++
  }

  function unpin(entryId) {
    Config.options.startPinnedApps = StartPin.unpin(Config.options.startPinnedApps, entryId)
    Config.options.startPinnedAppsSeeded = true
    root._revision++
  }

  function move(fromIndex, toIndex) {
    Config.options.startPinnedApps = StartPin.move(Config.options.startPinnedApps, fromIndex, toIndex)
    root._revision++
  }

  function isPinned(entryId) {
    return StartPin.isPinned(Config.options.startPinnedApps, entryId)
  }

  Connections {
    target: Config
    function onReadyChanged() {
      if (Config.ready)
        root.ensureSeeded()
    }
  }

  Component.onCompleted: Qt.callLater(root.ensureSeeded)
}
