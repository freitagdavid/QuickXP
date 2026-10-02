import QtQuick
import qs.QuickXP

// Left-column app row (pins / MFU) with optional drag reorder.
Item {
  id: root

  property var node: null
  property bool selected: false
  property int rowHeight: 32
  property bool draggable: false
  property int dragIndex: -1

  signal activated()
  signal hovered()
  signal unhovered()
  signal unpinRequested()
  signal dragFinished(int fromIndex, int toIndex)

  width: parent ? parent.width : 180
  height: rowHeight

  readonly property bool hot: selected || area.containsMouse
  property int dropTarget: -1

  Rectangle {
    anchors.fill: parent
    color: root.hot ? Theme.color("highlight", "#316AC5") : "transparent"
    radius: 2
  }

  Image {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    width: 32
    height: 32
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
    color: root.hot ? Theme.color("highlightText", "white") : "#000000"
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
        root.unpinRequested()
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
