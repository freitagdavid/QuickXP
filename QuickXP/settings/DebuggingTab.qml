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
        height: debugCol.height + 28
        title: "Start menu"

        Column {
          id: debugCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Developer aids for inspecting shell chrome. These options are not meant for normal use."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          XpCheckBox {
            text: "Keep Start menu open by default"
            checked: root.draft.debugKeepStartMenuOpen === true
            onToggled: root.draft.debugKeepStartMenuOpen = !root.draft.debugKeepStartMenuOpen
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Requires OK or Apply. Opens Start on load, disables outside-click grab dismiss, and re-opens after hot reload. The Start button can still toggle it closed."
            color: Theme.value("button", "disabledText", "#A1A192")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }
    }
  }
}
