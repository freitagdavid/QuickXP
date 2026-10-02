import QtQuick
import qs.QuickXP

// XP Start bottom bar: Log Off + Turn Off Computer (Luna LOGOFF art).
Item {
  id: root

  property var host: null

  readonly property int barHeight: Number(Theme.value("startPanel", "footerHeight", 39))
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
    border.left: 8
    border.right: 8
    border.top: 4
    border.bottom: 4
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: !barSkin.visible
    color: Theme.color("classicStartBannerMid", "#0A246A")
  }

  Row {
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    XpStartFooterButton {
      label: "Log Off"
      iconIndex: 1 // key glyph in LOGOFFBUTTONS strip
      host: root.host
      action: "logoff"
    }

    XpStartFooterButton {
      label: "Turn Off Computer"
      iconIndex: 2 // power glyph
      host: root.host
      action: "shutdown"
    }
  }
}
