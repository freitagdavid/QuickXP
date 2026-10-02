import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.controls

PopupWindow {
  id: root

  property Item anchorItem: null
  property int contentWidth: 280
  property int contentHeight: 220
  property string heading: ""
  // Cap flyout height; taller content scrolls inside.
  property int maxContentHeight: 360

  readonly property int gapAboveTaskbar: 8
  readonly property int chromeMargins: 16 // 8+8
  readonly property int headingBlock: heading !== "" ? 20 : 0

  visible: false
  color: Theme.color("menu", "#FFFFFF")
  grabFocus: true
  implicitWidth: contentWidth
  implicitHeight: Math.min(contentHeight, maxContentHeight)

  anchor.window: anchorItem !== null ? anchorItem.QsWindow.window : null
  anchor.edges: Edges.Top | Edges.Right
  anchor.gravity: Edges.Top | Edges.Left
  anchor.adjustment: PopupAdjustment.None
  anchor.margins.top: root.gapAboveTaskbar
  anchor.onAnchoring: {
    const item = root.anchorItem
    if (item === null)
      return
    const shellWindow = item.QsWindow
    if (shellWindow === null || shellWindow.contentItem === null)
      return
    const iconRight = shellWindow.contentItem.mapFromItem(item, item.width, 0)
    root.anchor.rect.x = iconRight.x
    root.anchor.rect.y = 0
    root.anchor.rect.width = 1
    root.anchor.rect.height = 1
  }

  function openAt(item) {
    root.anchorItem = item
    if (item && item.trayRoot && typeof item.trayRoot.hideTip === "function")
      item.trayRoot.hideTip(null)
    Qt.callLater(() => {
      if (root.anchorItem === null)
        return
      visible = true
      if (typeof root.anchor.updateAnchor === "function")
        root.anchor.updateAnchor()
    })
  }

  function close() {
    visible = false
  }

  onImplicitHeightChanged: {
    if (visible && typeof root.anchor.updateAnchor === "function")
      root.anchor.updateAnchor()
  }

  default property alias content: bodyCol.data

  Rectangle {
    anchors.fill: parent
    color: Theme.color("menu", "#FFFFFF")
    border.color: Theme.color("border", "#003C74")
    border.width: 1

    Text {
      id: headingLabel
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      anchors.topMargin: 8
      visible: root.heading !== ""
      height: visible ? implicitHeight : 0
      text: root.heading
      font.bold: true
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: 11
      color: Theme.color("menuText", "#000000")
    }

    XpScrollView {
      id: scroller
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: headingLabel.bottom
      anchors.bottom: parent.bottom
      anchors.leftMargin: 8
      anchors.rightMargin: 4
      anchors.topMargin: root.heading !== "" ? 6 : 8
      anchors.bottomMargin: 8

      Column {
        id: bodyCol
        width: parent.width
        spacing: 6
      }
    }
  }
}
