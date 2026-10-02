pragma Singleton

import QtQuick
import Quickshell
import qs.QuickXP
import "StartMfu.js" as StartMfu

Singleton {
  id: root

  property int _revision: 0
  readonly property int halfLifeDays: 7

  readonly property var mfuIds: {
    const _ = root._revision
    const __scores = Config.options.startMfuScores
    const __ex = Config.options.startMfuExcluded
    const __count = Config.options.startMfuCount
    const __pins = StartPinStore.pinIds
    return StartMfu.rankedIds(__scores, __ex, __pins, __count)
  }

  readonly property var mfuRows: {
    const ids = root.mfuIds
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
        icon: String(entry.icon || "")
      })
    }
    return rows
  }

  function bump(entryId) {
    if (!entryId)
      return
    Config.options.startMfuScores = StartMfu.bumpScore(
      Config.options.startMfuScores, entryId, root.halfLifeDays
    )
    root._revision++
  }

  // Remove from This List — does not unpin.
  function removeFromList(entryId) {
    Config.options.startMfuScores = StartMfu.removeFromList(Config.options.startMfuScores, entryId)
    Config.options.startMfuExcluded = StartMfu.exclude(Config.options.startMfuExcluded, entryId)
    root._revision++
  }

  function clearList() {
    Config.options.startMfuScores = StartMfu.clearList()
    Config.options.startMfuExcluded = "[]"
    root._revision++
  }

  Connections {
    target: Config.options
    function onStartMfuCountChanged() { root._revision++ }
    function onStartMfuScoresChanged() { root._revision++ }
    function onStartMfuExcludedChanged() { root._revision++ }
  }
}
