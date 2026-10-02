import QtQuick
import qs.QuickXP

// XP Start bottom bar — LOGOFF art + theme fill/text.
Item {
  id: root

  property var host: null

  readonly property int barHeight: Number(Theme.value("startPanel", "footerHeight", 40))
  readonly property int iconSize: 24

  height: barHeight
  implicitHeight: barHeight

  BorderImage {
    id: barSkin
    anchors.fill: parent
    source: {
      const path = Theme.image("startPanelLogoffBackgroundImage")
      return path ? ("file://" + path) : ""
    }
    border.left: Number(Theme.value("startPanel", "logoffBorderLeft", 49))
    border.right: Number(Theme.value("startPanel", "logoffBorderRight", 47))
    border.top: Number(Theme.value("startPanel", "logoffBorderTop", 0))
    border.bottom: Number(Theme.value("startPanel", "logoffBorderBottom", 38))
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: !barSkin.visible
    color: String(Theme.value("startPanel", "logoffFill", "#2577DF"))
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    XpStartFooterButton {
      label: "Log Off"
      iconIndex: 1
      host: root.host
      action: "logoff"
    }

    XpStartFooterButton {
      label: "Turn Off Computer"
      iconIndex: 2
      host: root.host
      action: "shutdown"
    }
  }
}
