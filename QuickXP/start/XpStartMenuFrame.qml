import QtQuick
import qs.QuickXP

// XP All Programs / places flyout chrome — StartGroupBackground (white + blue accent).
Item {
  id: root

  property alias contentItem: content
  readonly property color face: String(Theme.value("startGroup", "fill", Theme.color("menu", "#FFFFFF")))
  readonly property color accent: String(Theme.value("startGroup", "accent", "#307FE5"))
  readonly property color edge: String(Theme.value("startGroup", "edge", "#666666"))

  // Soft drop shadow (XP menus sit slightly above the desktop).
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: 2
    anchors.topMargin: 2
    color: "#40000000"
  }

  BorderImage {
    id: skin
    anchors.fill: parent
    source: {
      const path = Theme.image("startGroupBackgroundImage")
      return path ? ("file://" + path) : ""
    }
    border.left: Number(Theme.value("startGroup", "borderLeft", 6))
    border.right: Number(Theme.value("startGroup", "borderRight", 5))
    border.top: Number(Theme.value("startGroup", "borderTop", 3))
    border.bottom: Number(Theme.value("startGroup", "borderBottom", 4))
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  // Fallback when theme lacks StartGroup art: white face, blue left accent, thin edge.
  Item {
    anchors.fill: parent
    visible: !skin.visible

    Rectangle {
      anchors.fill: parent
      color: root.edge
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      color: root.face
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: 1
      width: Number(Theme.value("startGroup", "accentWidth", 6))
      color: root.accent
    }
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.leftMargin: Number(Theme.value("startGroup", "contentLeft", 2))
    anchors.rightMargin: Number(Theme.value("startGroup", "contentRight", 2))
    anchors.topMargin: Number(Theme.value("startGroup", "contentTop", 2))
    anchors.bottomMargin: Number(Theme.value("startGroup", "contentBottom", 2))
  }
}
