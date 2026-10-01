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
        height: sourceCol.height + 28
        title: "Programs menu"

        Column {
          id: sourceCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "How Classic Start builds the Programs cascade."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          XpRadioButton {
            text: "XDG applications menu (user + system)"
            checked: root.draft.startProgramsSource !== "categories"
            onToggled: root.draft.startProgramsSource = "xdgMenu"
          }

          XpRadioButton {
            text: "Category folders from installed apps"
            checked: root.draft.startProgramsSource === "categories"
            onToggled: root.draft.startProgramsSource = "categories"
          }
        }
      }
    }
  }
}
