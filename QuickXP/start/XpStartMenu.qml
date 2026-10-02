import QtQuick
import Quickshell
import qs.QuickXP

// XP dual-column Start shell. Filled in by Epic 2 tickets (#69–#77).
Item {
  id: root

  property var host: null
  property var programsNode: null

  readonly property int panelWidth: 380
  readonly property int panelHeight: 420

  width: panelWidth
  implicitHeight: panelHeight

  readonly property bool submenuOpen: false

  function closeSubmenus() {}
  function resetFocus() {}
  function handleKey(event) {
    if (!event)
      return
    event.accepted = false
  }

  // Stub chrome so layout switch is visible before #69 skins land.
  Rectangle {
    anchors.fill: parent
    color: Theme.color("classicMenu", "#ECE9D8")
    border.color: Theme.color("classicStartBannerMid", "#0A246A")
    border.width: 2

    Column {
      anchors.centerIn: parent
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Start"
        color: Theme.color("classicStartBannerMid", "#0A246A")
        font.pixelSize: 16
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "XP dual-column (loading…)"
        color: "#404040"
        font.pixelSize: 11
      }
    }
  }
}
