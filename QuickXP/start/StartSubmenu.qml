import QtQuick
import Quickshell
import qs.QuickXP
import "StartSubmenuChrome.js" as StartSubmenuChrome

PopupWindow {
  id: popup

  property var nodes: []
  property Item anchorItem: null
  property var host: null
  // First cascade from Start is bottom-aligned; each nested level flips.
  property bool alignBottom: false
  property int cascadeDepth: 0
  // "classic" → beige ClassicMenuFrame; "xp" → white StartGroup chrome.
  property string chrome: "classic"

  visible: false
  color: "transparent"
  // Outside click dismisses (same pattern as task strip / combo popups).
  grabFocus: true

  property bool armed: false
  property int openIndex: -1
  property var childMenu: null

  // grabFocus may hide us without close(); keep child/state in sync.
  onClosed: {
    armed = false
    openIndex = -1
    armTimer.stop()
    hoverOpen.stop()
    hoverOpen.pending = -1
    leaveClose.stop()
    if (childMenu)
      childMenu.close()
  }

  readonly property bool xpChrome: StartSubmenuChrome.isXp(popup.chrome)
  readonly property int menuWidth: xpChrome ? 180 : 200
  readonly property int itemRowHeight: StartSubmenuChrome.rowHeight(popup.chrome)
  readonly property int itemIconSize: StartSubmenuChrome.iconSize(popup.chrome)
  readonly property Item activeFrame: xpChrome ? xpFrame : classicFrame

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
    else
      childMenu.chrome = popup.chrome
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
    if (childMenu && childMenu.visible && openIndex !== index)
      childMenu.close()
    // ListView may not have instantiated an off-screen row yet.
    list.positionViewAtIndex(index, ListView.Contain)
    const delegate = list.itemAtIndex(index)
    if (!delegate)
      return
    const child = ensureChildMenu()
    if (!child)
      return
    openIndex = index
    child.chrome = popup.chrome
    child.cascadeDepth = popup.cascadeDepth + 1
    child.alignBottom = !popup.alignBottom
    child.nodes = node.children || []
    child.host = popup.host
    child.openAt(delegate)
  }

  readonly property real listContentHeight: {
    const nodes = popup.nodes || []
    let h = 0
    for (let i = 0; i < nodes.length; ++i) {
      const n = nodes[i]
      h += (n && n.kind === "separator") ? 9 : popup.itemRowHeight
    }
    return h
  }
  readonly property real panelHeight: Math.min(420, Math.max(28, listContentHeight + 8))

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

  // Close when the pointer leaves this flyout (and any open child) for a beat.
  Timer {
    id: leaveClose
    interval: 280
    onTriggered: {
      if (popup.childMenu && popup.childMenu.visible)
        return
      popup.close()
      if (popup.host && typeof popup.host.onFlyoutLeft === "function")
        popup.host.onFlyoutLeft()
    }
  }

  function onFrameHoverChanged(hovered) {
    if (hovered) {
      leaveClose.stop()
      if (popup.host && typeof popup.host.pokeSuppress === "function")
        popup.host.pokeSuppress()
      return
    }
    if (popup.armed && popup.visible)
      leaveClose.restart()
  }

  anchor.item: anchorItem
  anchor.edges: popup.alignBottom ? (Edges.Bottom | Edges.Right) : (Edges.Top | Edges.Right)
  anchor.gravity: popup.alignBottom ? (Edges.Top | Edges.Right) : (Edges.Bottom | Edges.Right)
  anchor.adjustment: PopupAdjustment.Slide

  implicitWidth: menuWidth
  implicitHeight: panelHeight

  ClassicMenuFrame {
    id: classicFrame
    anchors.fill: parent
    visible: !popup.xpChrome
    implicitHeight: popup.panelHeight

    HoverHandler {
      onHoveredChanged: popup.onFrameHoverChanged(hovered)
    }
  }

  XpStartMenuFrame {
    id: xpFrame
    anchors.fill: parent
    visible: popup.xpChrome
    implicitHeight: popup.panelHeight

    HoverHandler {
      onHoveredChanged: popup.onFrameHoverChanged(hovered)
    }
  }

  ListView {
    id: list
    parent: popup.activeFrame.contentItem
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: popup.xpChrome ? 1 : 2
    height: Math.max(0, popup.panelHeight - 8)
    clip: true
    spacing: 0
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    model: popup.nodes

    delegate: StartMenuItem {
      required property var modelData
      required property int index

      width: list.width
      node: modelData
      chrome: popup.chrome
      rowHeight: popup.itemRowHeight
      iconSize: popup.itemIconSize
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
      onContextMenuRequested: {
        if (!modelData || modelData.kind !== "app")
          return
        if (popup.host && typeof popup.host.openAppContextMenu === "function")
          popup.host.openAppContextMenu(this, modelData.entryId || modelData.id, false)
      }
    }
  }
}
