import QtQuick
import qs.QuickXP

// Left-column app row (pins / MFU) — colors/sizes from Theme.startPanel.
Item {
  id: root

  property var node: null
  property bool selected: false
  property int rowHeight: Number(Theme.value("startPanel", "rowHeight", 32))
  property int iconSize: Number(Theme.value("startPanel", "iconSize", 32))
  property bool draggable: false
  property int dragIndex: -1

  signal activated()
  signal hovered()
  signal unhovered()
  signal unpinRequested()
  signal contextMenuRequested()
  signal dragFinished(int fromIndex, int toIndex)

  width: parent ? parent.width : 180
  height: rowHeight

  readonly property bool hot: selected || area.containsMouse
  readonly property color mfuHot: String(Theme.value("startPanel", "mfuHot", Theme.color("highlight", "#316AC5")))
  readonly property color mfuText: String(Theme.value("startPanel", "mfuText", "#373738"))
  readonly property color mfuHotText: String(Theme.value("startPanel", "mfuHotText", Theme.color("highlightText", "#FFFFFF")))

  Rectangle {
    anchors.fill: parent
    color: root.hot ? root.mfuHot : "transparent"
    radius: 2
  }

  Image {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: 2
    anchors.verticalCenter: parent.verticalCenter
    width: root.iconSize
    height: root.iconSize
    sourceSize.width: root.iconSize
    sourceSize.height: root.iconSize
    source: {
      if (!root.node)
        return ""
      const raw = String(root.node.icon || "")
      if (!raw)
        return ""
      if (raw.startsWith("file:") || raw.startsWith("image:"))
        return raw
      if (raw.startsWith("/"))
        return "file://" + raw
      return "image://icon/" + raw
    }
    fillMode: Image.PreserveAspectFit
    smooth: true
    asynchronous: true
  }

  Text {
    anchors.left: icon.right
    anchors.leftMargin: 6
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: root.node ? String(root.node.label || "") : ""
    color: root.hot ? root.mfuHotText : root.mfuText
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    font.bold: !!(root.node && root.node.bold)
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    drag.target: root.draggable ? root : undefined
    drag.axis: Drag.YAxis
    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
        root.contextMenuRequested()
        return
      }
      root.activated()
    }
    onEntered: root.hovered()
    onExited: root.unhovered()
    onReleased: {
      if (!root.draggable || root.dragIndex < 0)
        return
      const parentCol = root.parent
      if (!parentCol)
        return
      const y = root.y + root.height / 2
      let to = root.dragIndex
      for (let i = 0; i < parentCol.children.length; ++i) {
        const child = parentCol.children[i]
        if (!child || child === root || child.dragIndex === undefined)
          continue
        if (y >= child.y && y < child.y + child.height) {
          to = child.dragIndex
          break
        }
      }
      root.y = 0
      if (to !== root.dragIndex)
        root.dragFinished(root.dragIndex, to)
    }
  }
}
