import QtQuick
import qs.QuickXP

// Right-column places row — text/hot/separator colors from Theme.startPanel.
Item {
  id: root

  property var node: null
  property bool selected: false
  property bool hasSubmenu: node && node.kind === "folder"
  property bool separator: node && node.kind === "separator"
  property int rowHeight: Number(Theme.value("startPanel", "placeRowHeight", 26))
  property int iconSize: Number(Theme.value("startPanel", "placeIconSize", 24))

  signal activated()
  signal hovered()
  signal unhovered()

  width: parent ? parent.width : 180
  height: separator ? 9 : rowHeight
  clip: true

  readonly property bool hot: selected || area.containsMouse
  readonly property color placeHighlight: String(Theme.value("startPanel", "placesHot", Theme.color("highlight", "#316AC5")))
  readonly property color placeText: String(Theme.value("startPanel", "placesText", "#0A246A"))
  readonly property color placeHotText: String(Theme.value("startPanel", "placesHotText", Theme.color("highlightText", "#FFFFFF")))
  readonly property color sepColor: String(Theme.value("startPanel", "placesSeparator", "#7BA0D0"))
  readonly property int glyphSize: Math.min(iconSize, Math.max(12, rowHeight - 2))

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

    Image {
      id: sepSkin
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: Math.min(sourceSize.height || 2, 4)
      source: {
        const path = Theme.image("startPanelPlacesSeparatorImage")
        return path ? ("file://" + path) : ""
      }
      fillMode: Image.Stretch
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      visible: !sepSkin.visible
      color: root.sepColor
    }
    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      visible: !sepSkin.visible
      color: Theme.color("menu", "#FFFFFF")
    }
  }

  Image {
    id: icon
    visible: !root.separator
    anchors.left: parent.left
    anchors.leftMargin: 2
    anchors.verticalCenter: parent.verticalCenter
    width: root.glyphSize
    height: root.glyphSize
    sourceSize.width: root.glyphSize
    sourceSize.height: root.glyphSize
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
    clip: true
    maximumLineCount: 1
    wrapMode: Text.NoWrap
    text: root.node ? String(root.node.label || "") : ""
    color: root.hot ? root.placeHotText : root.placeText
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    font.bold: !!(root.node && root.node.bold)
  }

  Canvas {
    id: cascade
    visible: root.hasSubmenu
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.verticalCenter: parent.verticalCenter
    width: 5
    height: 9
    onPaint: {
      const ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = root.hot ? root.placeHotText : root.placeText
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
      function onPlaceTextChanged() { cascade.requestPaint() }
      function onPlaceHotTextChanged() { cascade.requestPaint() }
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
