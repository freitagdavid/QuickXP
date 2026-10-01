import QtQuick
import QtQuick.Controls
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

    Column {
      id: column
      width: parent.width
      spacing: 12

      XpGroupBox {
        width: parent.width
        height: columnChecks.height + 28
        title: "Taskbar appearance"

        Column {
          id: columnChecks
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          XpCheckBox {
            text: "Lock the taskbar"
            checked: root.draft.taskbarLocked
            onToggled: root.draft.taskbarLocked = !root.draft.taskbarLocked
          }

          XpCheckBox {
            text: "Auto-hide the taskbar"
            checked: root.draft.autoHide
            onToggled: root.draft.autoHide = !root.draft.autoHide
          }

          XpCheckBox {
            text: "Group similar taskbar buttons"
            checked: root.draft.groupButtons
            onToggled: root.draft.groupButtons = !root.draft.groupButtons
          }

          XpCheckBox {
            text: "Icons only"
            checked: root.draft.iconsOnly
            onToggled: root.draft.iconsOnly = !root.draft.iconsOnly
          }

          XpCheckBox {
            text: "Show Quick Launch"
            checked: root.draft.showQuickLaunch
            onToggled: root.draft.showQuickLaunch = !root.draft.showQuickLaunch
          }
        }
      }

      XpGroupBox {
        width: parent.width
        height: 56
        title: "Presets"

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          XpPushButton {
            text: "Windows XP taskbar"
            onClicked: {
              root.draft.groupButtons = true
              root.draft.iconsOnly = false
            }
          }

          XpPushButton {
            text: "Icon taskbar with previews"
            onClicked: {
              root.draft.groupButtons = true
              root.draft.iconsOnly = true
            }
          }
        }
      }

      XpGroupBox {
        width: parent.width
        height: 64
        title: "Taskbar height"

        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 10

          Slider {
            id: heightSlider
            width: parent.width - 56
            from: 24
            to: 72
            stepSize: 1
            value: root.draft.taskbarHeight > 0
              ? root.draft.taskbarHeight
              : Theme.sizes.taskbarHeight
            onMoved: root.draft.taskbarHeight = Math.round(value)
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(heightSlider.value) + " px"
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }

      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Grouping, icon-only mode, auto-hide, and Quick Launch behavior will take effect as those features land. Height applies immediately on Apply."
        color: Theme.color("windowText", "black")
        font.family: Theme.value("fonts", "ui", "Tahoma")
        font.pixelSize: Theme.size("fontSize", 11)
        opacity: 0.75
      }
    }
  }
}
