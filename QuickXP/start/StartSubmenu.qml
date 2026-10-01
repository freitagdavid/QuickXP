import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
  id: popup

  property var nodes: []
  property Item anchorItem: null
  // ClassicStartMenu (or compatible) with activateNode(node)
  property var host: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: false

  property bool armed: false
  property int openIndex: -1
  property var childMenu: null

  readonly property int menuWidth: 200

  function openAt(item) {
    anchorItem = item
    armed = false
    openIndex = -1
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
    })
  }

  function close() {
    visible = false
    armed = false
    openIndex = -1
    armTimer.stop()
    hoverOpen.stop()
    if (childMenu)
      childMenu.close()
  }

  function activateNode(node) {
    if (!host || !node)
      return
    host.activateNode(node)
  }

  function ensureChildMenu() {
    if (childMenu)
      return childMenu
    childMenu = childComponent.createObject(popup)
    return childMenu
  }

  function openChildFor(index) {
    const node = popup.nodes[index]
    if (!node || node.kind !== "folder") {
      if (childMenu)
        childMenu.close()
      return
    }
    const delegate = list.itemAt(index)
    if (!delegate)
      return
    const child = ensureChildMenu()
    child.nodes = node.children || []
    child.host = popup.host
    child.openAt(delegate)
  }

  Timer {
    id: armTimer
    interval: 200
    onTriggered: popup.armed = true
  }

  Timer {
    id: hoverOpen
    interval: 300
    property int pending: -1
    onTriggered: {
      if (pending < 0)
        return
      popup.openIndex = pending
      popup.openChildFor(pending)
    }
  }

  Component {
    id: childComponent
    StartSubmenu {}
  }

  anchor.item: anchorItem
  anchor.edges: Edges.Top | Edges.Right
  anchor.gravity: Edges.Top | Edges.Right
  anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

  implicitWidth: menuWidth
  implicitHeight: Math.min(420, Math.max(28, column.implicitHeight + 4))

  Rectangle {
    anchors.fill: parent
    color: Theme.color("menu", "white")
    border.width: 1
    border.color: Theme.color("border", "#003C74")

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 2
      spacing: 0

      Repeater {
        id: list
        model: popup.nodes

        delegate: StartMenuItem {
          required property var modelData
          required property int index

          node: modelData
          selected: popup.openIndex === index
          onActivated: {
            if (modelData && modelData.kind === "folder") {
              hoverOpen.pending = index
              hoverOpen.interval = 0
              hoverOpen.restart()
              hoverOpen.interval = 300
            } else {
              popup.activateNode(modelData)
            }
          }
          onHovered: {
            hoverOpen.pending = index
            hoverOpen.restart()
            if (modelData && modelData.kind !== "folder" && popup.childMenu)
              popup.childMenu.close()
          }
        }
      }
    }
  }
}
