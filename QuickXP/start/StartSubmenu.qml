import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
  id: popup

  property var nodes: []
  property Item anchorItem: null
  property var host: null
  // First cascade from Start is bottom-aligned; each nested level flips.
  property bool alignBottom: false
  property int cascadeDepth: 0

  visible: false
  color: "transparent"
  grabFocus: false

  property bool armed: false
  property int openIndex: -1
  property var childMenu: null

  readonly property int menuWidth: 200
  readonly property int itemRowHeight: 18

  function openAt(item) {
    if (childMenu)
      childMenu.close()
    openIndex = -1
    hoverOpen.stop()
    hoverOpen.pending = -1
    anchorItem = item
    armed = false
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
    hoverOpen.pending = -1
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
    const comp = Qt.createComponent(Qt.resolvedUrl("StartSubmenu.qml"))
    if (comp.status === Component.Error) {
      console.warn("QuickXP StartSubmenu: create failed:", comp.errorString())
      return null
    }
    if (comp.status !== Component.Ready) {
      console.warn("QuickXP StartSubmenu: component not ready:", comp.status)
      return null
    }
    childMenu = comp.createObject(popup)
    if (!childMenu)
      console.warn("QuickXP StartSubmenu: createObject failed")
    return childMenu
  }

  function openChildFor(index) {
    const node = popup.nodes[index]
    if (!node || node.kind !== "folder") {
      if (childMenu)
        childMenu.close()
      openIndex = -1
      return
    }
    // Only one open flyout at this level.
    if (childMenu && childMenu.visible && openIndex !== index)
      childMenu.close()
    const delegate = list.itemAt(index)
    if (!delegate)
      return
    const child = ensureChildMenu()
    if (!child)
      return
    openIndex = index
    child.cascadeDepth = popup.cascadeDepth + 1
    child.alignBottom = !popup.alignBottom
    child.nodes = node.children || []
    child.host = popup.host
    child.openAt(delegate)
  }

  function requestOpen(index) {
    if (index < 0)
      return
    hoverOpen.pending = index
    hoverOpen.restart()
  }

  function requestOpenNow(index) {
    hoverOpen.stop()
    hoverOpen.pending = -1
    openChildFor(index)
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
      const idx = pending
      pending = -1
      if (idx < 0)
        return
      popup.openChildFor(idx)
    }
  }

  // Attach to the parent row's right edge; gravity uses the opposite vertical
  // side so the flyout sits beside the row (tops or bottoms flush), not
  // corner-to-corner diagonally. Same pattern as XpComboBox dropdowns.
  anchor.item: anchorItem
  anchor.edges: popup.alignBottom ? (Edges.Bottom | Edges.Right) : (Edges.Top | Edges.Right)
  anchor.gravity: popup.alignBottom ? (Edges.Top | Edges.Right) : (Edges.Bottom | Edges.Right)
  anchor.adjustment: PopupAdjustment.Slide

  implicitWidth: menuWidth
  implicitHeight: Math.min(420, Math.max(28, frame.implicitHeight))

  ClassicMenuFrame {
    id: frame
    anchors.fill: parent
    implicitHeight: column.implicitHeight + 8

    HoverHandler {
      // Keep parent Start from dismissing while the pointer is in this flyout.
      onHoveredChanged: {
        if (hovered && popup.host && typeof popup.host.pokeSuppress === "function")
          popup.host.pokeSuppress()
      }
    }

    Column {
      id: column
      parent: frame.contentItem
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
          rowHeight: popup.itemRowHeight
          selected: popup.openIndex === index
          onActivated: {
            if (modelData && modelData.kind === "folder")
              popup.requestOpenNow(index)
            else
              popup.activateNode(modelData)
          }
          onHovered: {
            if (!modelData || modelData.kind === "separator")
              return
            if (modelData.kind === "folder") {
              popup.requestOpen(index)
            } else {
              hoverOpen.stop()
              hoverOpen.pending = -1
              popup.openIndex = -1
              if (popup.childMenu)
                popup.childMenu.close()
            }
          }
        }
      }
    }
  }
}
