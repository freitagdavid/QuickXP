import QtQuick
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

Column {
  id: root

  property var host: null
  property var programsNode: null

  width: parent ? parent.width : 200
  spacing: 0

  readonly property var rootRows: {
    const programs = programsNode && programsNode.kind === "folder"
      ? programsNode
      : StartMenuModel.folderNode("programs", "Programs", "", [])
    const shell = StartMenuModel.classicShellItems()
    const session = StartMenuModel.classicSessionItems()
    return [programs].concat(shell).concat(session)
  }

  property int openIndex: -1
  readonly property bool submenuOpen: submenu.visible

  function activateNode(node) {
    if (!host || !node)
      return
    if (node.kind === "app") {
      const entry = AppCatalog.byId(node.entryId || node.id)
      if (entry && AppCatalog.launch(entry))
        host.close()
      return
    }
    if (node.kind === "folder")
      return
    if (node.kind === "action" && typeof host.runAction === "function")
      host.runAction(node.action)
  }

  Timer {
    id: hoverOpen
    interval: 300
    property int pending: -1
    onTriggered: {
      if (pending < 0)
        return
      root.openIndex = pending
      const node = root.rootRows[pending]
      if (!node || node.kind !== "folder") {
        if (submenu.visible)
          submenu.close()
        return
      }
      const delegate = rowList.itemAt(pending)
      if (!delegate)
        return
      submenu.nodes = node.children || []
      submenu.host = root
      submenu.openAt(delegate)
    }
  }

  function closeSubmenus() {
    openIndex = -1
    hoverOpen.stop()
    if (submenu.visible)
      submenu.close()
  }

  Repeater {
    id: rowList
    model: root.rootRows

    delegate: StartMenuItem {
      required property var modelData
      required property int index

      node: modelData
      selected: root.openIndex === index && modelData && modelData.kind === "folder"
      onActivated: {
        if (modelData && modelData.kind === "folder") {
          hoverOpen.pending = index
          hoverOpen.interval = 0
          hoverOpen.restart()
          hoverOpen.interval = 300
        } else if (modelData && modelData.kind === "separator") {
          // no-op
        } else {
          root.activateNode(modelData)
        }
      }
      onHovered: {
        if (modelData && modelData.kind === "separator")
          return
        hoverOpen.pending = index
        hoverOpen.restart()
      }
    }
  }

  StartSubmenu {
    id: submenu
    host: root
  }
}
