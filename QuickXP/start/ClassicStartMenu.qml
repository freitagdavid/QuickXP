import QtQuick
import qs.QuickXP

Column {
  id: root

  property var host: null
  property var programsNode: null

  width: parent ? parent.width : 200
  spacing: 0

  readonly property var programsChildren: {
    const node = programsNode
    if (!node || !node.children)
      return []
    return node.children
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
    if (node.kind === "folder") {
      // click on folder keeps flyout; hover opens
      return
    }
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
      const node = root.programsChildren[pending]
      if (!node || node.kind !== "folder") {
        if (submenu.visible)
          submenu.close()
        return
      }
      const delegate = programsList.itemAt(pending)
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

  // Programs cascade root rows (category / XDG folders and apps).
  Repeater {
    id: programsList
    model: root.programsChildren

    delegate: StartMenuItem {
      required property var modelData
      required property int index

      node: modelData
      selected: root.openIndex === index
      onActivated: {
        if (modelData && modelData.kind === "folder") {
          hoverOpen.pending = index
          hoverOpen.interval = 0
          hoverOpen.restart()
          hoverOpen.interval = 300
        } else {
          root.activateNode(modelData)
        }
      }
      onHovered: {
        hoverOpen.pending = index
        hoverOpen.restart()
      }
    }
  }

  Item {
    width: parent.width
    height: 28
    visible: root.programsChildren.length === 0

    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: 8
      text: "No programs"
      color: Theme.value("button", "disabledText", "#A1A192")
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: Theme.size("fontSize", 11)
    }
  }

  StartSubmenu {
    id: submenu
    host: root
  }
}
