import QtQuick
import qs.QuickXP

// Right-column places row (smaller icons, Luna blue highlight).
Item {
  id: root

  property var node: null
  property bool selected: false
  property bool hasSubmenu: node && node.kind === "folder"
  property bool separator: node && node.kind === "separator"
  property int rowHeight: 28

  signal activated()
  signal hovered()
  signal unhovered()

  width: parent ? parent.width : 180
  height: separator ? 9 : rowHeight

  readonly property bool hot: selected || area.containsMouse
  readonly property color placeHighlight: Theme.color("highlight", "#316AC5")

  Rectangle {
    anchors.fill: parent
    visible: !root.separator
    color: root.hot ? root.placeHighlight : "transparent"
    radius: 2
  }

  Item {
    visible: root.separator
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 4
    anchors.rightMargin: 4
    height: 2
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      color: "#7BA0D0"
    }
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: "#FFFFFF"
    }
  }

  Image {
    id: icon
    visible: !root.separator
    anchors.left: parent.left
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: 24
    height: 24
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
    visible: !root.separator
    anchors.left: icon.right
    anchors.leftMargin: 6
    anchors.right: cascade.left
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    text: root.node ? String(root.node.label || "") : ""
    color: root.hot ? Theme.color("highlightText", "white") : "#000000"
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    font.bold: !!(root.node && root.node.bold)
  }

  Canvas {
    id: cascade
    visible: root.hasSubmenu
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    width: 5
    height: 9
    onPaint: {
      const ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = root.hot ? "#FFFFFF" : "#215DC6"
      ctx.beginPath()
      ctx.moveTo(0, 0)
      ctx.lineTo(width, height / 2)
      ctx.lineTo(0, height)
      ctx.closePath()
      ctx.fill()
    }
    onVisibleChanged: requestPaint()
    Connections {
      target: root
      function onHotChanged() { cascade.requestPaint() }
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    enabled: !root.separator
    onClicked: root.activated()
    onEntered: root.hovered()
    onExited: root.unhovered()
  }
}
