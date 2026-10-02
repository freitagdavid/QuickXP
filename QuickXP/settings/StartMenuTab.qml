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

      XpGroupBox {
        width: parent.width
        height: advancedCol.height + 28
        title: "Advanced"

        Column {
          id: advancedCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          XpCheckBox {
            text: "Highlight newly installed programs"
            checked: root.draft.startHighlightNew === true
            onToggled: root.draft.startHighlightNew = !root.draft.startHighlightNew
          }

          XpCheckBox {
            text: "Use personalized menus (hide rarely used)"
            checked: root.draft.startPersonalizedMenus === true
            onToggled: root.draft.startPersonalizedMenus = !root.draft.startPersonalizedMenus
          }

          Row {
            spacing: 8
            XpPushButton {
              text: "Clear highlight list"
              onClicked: StartHighlightStore.clearHighlights()
            }
            XpPushButton {
              text: "Clear recent documents"
              onClicked: RecentCatalog.clearRecent()
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Clear buttons apply immediately. Other options use OK / Apply."
            color: Theme.value("button", "disabledText", "#A1A192")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }
    }
  }
}
