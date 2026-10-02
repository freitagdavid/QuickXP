import QtQuick
import qs.QuickXP

Item {
  id: root

  property var node: null
  property bool selected: false
  property bool hasSubmenu: node && node.kind === "folder"
  property bool separator: node && node.kind === "separator"
  // XP classic Start large-icon row (32px icon fills the row).
  property int rowHeight: 32

  signal activated()
  signal hovered()
  signal unhovered()

  width: parent ? parent.width : 180
  height: separator ? 9 : rowHeight

  readonly property bool hot: selected || area.containsMouse
  readonly property color classicHighlight: Theme.color("classicMenuHighlight", "#0A246A")

  Rectangle {
    anchors.fill: parent
    visible: !root.separator
    color: root.hot ? root.classicHighlight : "transparent"
  }

  // Etched separator (classic light/dark pair)
  Item {
    visible: root.separator
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 2
    anchors.rightMargin: 2
    height: 2

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      color: "#808080"
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
    id: label
    visible: !root.separator
    anchors.left: icon.right
    anchors.leftMargin: 6
    anchors.right: cascade.left
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
    textFormat: Text.RichText
    text: root.mnemonicLabel
    color: root.hot ? Theme.color("highlightText", "white") : Theme.color("menuText", "black")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    font.bold: !!(root.node && (root.node.isNew || root.node.hasNew))
  }

  readonly property string mnemonicLabel: {
    if (!root.node)
      return ""
    const raw = String(root.node.label || "")
    const key = String(root.node.mnemonic || "").toLowerCase()
    if (!key || key.length !== 1)
      return escapeXml(raw)
    const lower = raw.toLowerCase()
    const idx = lower.indexOf(key)
    if (idx < 0)
      return escapeXml(raw)
    return escapeXml(raw.slice(0, idx))
      + "<u>" + escapeXml(raw.slice(idx, idx + 1)) + "</u>"
      + escapeXml(raw.slice(idx + 1))
  }

  function escapeXml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }

  // Classic black cascade triangle
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
      ctx.fillStyle = root.hot ? "#FFFFFF" : "#000000"
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
