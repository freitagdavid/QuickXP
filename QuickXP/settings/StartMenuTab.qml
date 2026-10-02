import QtQuick
import qs.QuickXP
import qs.QuickXP.controls

Item {
  id: root

  required property var draft

  function placeModeLabel(mode) {
    const m = String(mode || "link")
    if (m === "menu")
      return "Display as a menu"
    if (m === "hidden")
      return "Don't display this item"
    return "Display as a link"
  }

  function placeValue(prop) {
    return String(root.draft[prop] || "link")
  }

  function cyclePlace(prop) {
    const cur = placeValue(prop)
    const next = cur === "link" ? "menu" : (cur === "menu" ? "hidden" : "link")
    if (prop === "startPlaceDocuments") root.draft.startPlaceDocuments = next
    else if (prop === "startPlaceRecentDocuments") root.draft.startPlaceRecentDocuments = next
    else if (prop === "startPlacePictures") root.draft.startPlacePictures = next
    else if (prop === "startPlaceMusic") root.draft.startPlaceMusic = next
    else if (prop === "startPlaceComputer") root.draft.startPlaceComputer = next
    else if (prop === "startPlaceNetwork") root.draft.startPlaceNetwork = next
    else if (prop === "startPlaceControlPanel") root.draft.startPlaceControlPanel = next
    else if (prop === "startPlaceConnectTo") root.draft.startPlaceConnectTo = next
    else if (prop === "startPlacePrinters") root.draft.startPlacePrinters = next
    else if (prop === "startPlaceAdminTools") root.draft.startPlaceAdminTools = next
  }

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
        height: layoutCol.height + 28
        title: "Start menu layout"

        Column {
          id: layoutCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Classic vs XP dual-column is controlled under Theme → Start menu layout (generation override)."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }

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
            text: "How Classic Start / All Programs builds the Programs cascade."
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
        height: mfuCol.height + 28
        title: "XP most frequently used"

        Column {
          id: mfuCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Number of programs on the XP Start left column (below pinned apps)."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          Row {
            spacing: 8
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Number of programs on Start menu:"
              color: Theme.color("windowText", "black")
              font.family: Theme.value("fonts", "ui", "Tahoma")
              font.pixelSize: Theme.size("fontSize", 11)
            }
            XpSpinBox {
              width: 72
              from: 0
              to: 30
              value: root.draft.startMfuCount
              onValueModified: root.draft.startMfuCount = value
            }
          }

          XpPushButton {
            text: "Clear List"
            onClicked: StartMfuStore.clearList()
          }
        }
      }

      XpGroupBox {
        width: parent.width
        height: placesCol.height + 28
        title: "XP special folders"

        Column {
          id: placesCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 4

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Click a row to cycle link / menu / hidden (Apply to save)."
            color: Theme.value("button", "disabledText", "#A1A192")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          Repeater {
            model: [
              { prop: "startPlaceDocuments", label: "My Documents" },
              { prop: "startPlaceRecentDocuments", label: "My Recent Documents" },
              { prop: "startPlacePictures", label: "My Pictures" },
              { prop: "startPlaceMusic", label: "My Music" },
              { prop: "startPlaceComputer", label: "My Computer" },
              { prop: "startPlaceNetwork", label: "My Network Places" },
              { prop: "startPlaceControlPanel", label: "Control Panel" },
              { prop: "startPlaceConnectTo", label: "Connect To" },
              { prop: "startPlacePrinters", label: "Printers and Faxes" },
              { prop: "startPlaceAdminTools", label: "Administrative Tools" }
            ]

            Item {
              required property var modelData
              width: placesCol.width
              height: 22

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.45
                elide: Text.ElideRight
                text: modelData.label
                color: Theme.color("windowText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.52
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: root.placeModeLabel(root.placeValue(modelData.prop))
                color: Theme.color("highlight", "#316AC5")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cyclePlace(modelData.prop)
              }
            }
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
