import QtQuick
import qs.QuickXP

Item {
  id: root

  property var node: null
  property bool selected: false
  property bool hasSubmenu: node && node.kind === "folder"
  property bool separator: node && node.kind === "separator"

  signal activated()
  signal hovered()
  signal unhovered()

  width: parent ? parent.width : 180
  height: separator ? 9 : 28

  readonly property bool hot: selected || area.containsMouse

  Rectangle {
    anchors.fill: parent
    visible: !root.separator
    color: root.hot ? Theme.color("highlight", "#316AC5") : "transparent"
  }

  Rectangle {
    visible: root.separator
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 4
    anchors.rightMargin: 4
    height: 1
    color: Theme.color("border", "#003C74")
    opacity: 0.35
  }

  Image {
    id: icon
    visible: !root.separator
    anchors.left: parent.left
    anchors.leftMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    width: 16
    height: 16
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
    text: root.node ? (root.node.label || "") : ""
    color: root.hot ? Theme.color("highlightText", "white") : Theme.color("menuText", "black")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }

  Text {
    id: cascade
    visible: root.hasSubmenu
    anchors.right: parent.right
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: "▸"
    color: root.hot ? Theme.color("highlightText", "white") : Theme.color("menuText", "black")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
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
