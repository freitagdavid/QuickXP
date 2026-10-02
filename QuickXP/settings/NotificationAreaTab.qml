import QtQuick
import qs.QuickXP
import qs.QuickXP.controls

Item {
  id: root

  required property var draft

  Flickable {
    anchors.fill: parent
    anchors.margins: 12
    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
      id: column
      width: parent.width
      spacing: 12

      XpGroupBox {
        width: parent.width
        height: checks.height + 28
        title: "System icons"

        Column {
          id: checks
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          XpCheckBox {
            text: "Volume"
            checked: root.draft.trayShowVolume
            onToggled: root.draft.trayShowVolume = !root.draft.trayShowVolume
          }
          XpCheckBox {
            text: "Network"
            checked: root.draft.trayShowNetwork
            onToggled: root.draft.trayShowNetwork = !root.draft.trayShowNetwork
          }
          XpCheckBox {
            text: "Bluetooth"
            checked: root.draft.trayShowBluetooth
            onToggled: root.draft.trayShowBluetooth = !root.draft.trayShowBluetooth
          }
          XpCheckBox {
            text: "Brightness"
            checked: root.draft.trayShowBrightness
            onToggled: root.draft.trayShowBrightness = !root.draft.trayShowBrightness
          }
          XpCheckBox {
            text: "Battery"
            checked: root.draft.trayShowBattery
            onToggled: root.draft.trayShowBattery = !root.draft.trayShowBattery
          }
          XpCheckBox {
            text: "Removable drives"
            checked: root.draft.trayShowDrives
            onToggled: root.draft.trayShowDrives = !root.draft.trayShowDrives
          }
          XpCheckBox {
            text: "Show Clock"
            checked: root.draft.trayShowClock
            onToggled: root.draft.trayShowClock = !root.draft.trayShowClock
          }
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Icons also hide automatically when the matching hardware or service is unavailable. Disable Plasma’s own volume/network applets if you see duplicates."
        font.pixelSize: 11
        font.family: Theme.value("fonts", "ui", "Tahoma")
        color: Theme.color("windowText", "#000000")
      }
    }
  }
}
