pragma Singleton

import QtQuick
import Quickshell
import qs.QuickXP
import "QuickLaunchModel.js" as QuickLaunchModel

Singleton {
  id: root

  property int _revision: 0

  readonly property var ids: {
    const _ = root._revision
    const __seeded = Config.options.quickLaunchSeeded
    const __raw = Config.options.quickLaunchIds
    return QuickLaunchModel.parseIds(__raw)
  }

  readonly property string showDesktopId: QuickLaunchModel.showDesktopId()

  function ensureSeeded() {
    if (!Config.ready)
      return
    if (Config.options.quickLaunchSeeded)
      return
    const defaults = QuickLaunchModel.defaultIds(AppCatalog.applications)
    Config.options.quickLaunchIds = QuickLaunchModel.idsJson(defaults)
    Config.options.quickLaunchSeeded = true
    root._revision++
  }

  function add(entryId, index) {
    Config.options.quickLaunchIds = QuickLaunchModel.insert(
      Config.options.quickLaunchIds, entryId, index)
    Config.options.quickLaunchSeeded = true
    root._revision++
  }

  function remove(entryId) {
    Config.options.quickLaunchIds = QuickLaunchModel.remove(
      Config.options.quickLaunchIds, entryId)
    Config.options.quickLaunchSeeded = true
    root._revision++
  }

  function move(fromIndex, toIndex) {
    Config.options.quickLaunchIds = QuickLaunchModel.move(
      Config.options.quickLaunchIds, fromIndex, toIndex)
    root._revision++
  }

  function isShowDesktop(id) {
    return QuickLaunchModel.isShowDesktop(id)
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
