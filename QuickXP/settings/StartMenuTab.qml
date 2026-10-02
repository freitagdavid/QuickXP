import QtQuick
import qs.QuickXP
import qs.QuickXP.controls

Item {
  id: root

  required property var draft

  function placeValue(prop) {
    return String(root.draft[prop] || "link")
  }

  function setPlace(prop, value) {
    const next = String(value || "link")
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
    else if (prop === "startPlaceHelp") root.draft.startPlaceHelp = next
    else if (prop === "startPlaceSearch") root.draft.startPlaceSearch = next
    else if (prop === "startPlaceRun") root.draft.startPlaceRun = next
  }

  function setPlaceShown(prop, shown) {
    if (!shown) {
      setPlace(prop, "hidden")
      return
    }
    const cur = placeValue(prop)
    setPlace(prop, cur === "hidden" ? "link" : cur)
  }

  function togglePlaceStyle(prop) {
    const cur = placeValue(prop)
    if (cur === "hidden")
      return
    setPlace(prop, cur === "menu" ? "link" : "menu")
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
        title: "XP right column (places)"

        Column {
          id: placesCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 4

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Enable items on the light-blue Start column. When enabled, click the style to switch link vs menu. Apply to save."
            color: Theme.value("button", "disabledText", "#A1A192")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          Repeater {
            model: [
              { prop: "startPlaceDocuments", label: "My Documents", allowMenu: true },
              { prop: "startPlaceRecentDocuments", label: "My Recent Documents", allowMenu: true },
              { prop: "startPlacePictures", label: "My Pictures", allowMenu: true },
              { prop: "startPlaceMusic", label: "My Music", allowMenu: true },
              { prop: "startPlaceComputer", label: "My Computer", allowMenu: true },
              { prop: "startPlaceNetwork", label: "My Network Places", allowMenu: true },
              { prop: "startPlaceControlPanel", label: "Control Panel", allowMenu: true },
              { prop: "startPlaceConnectTo", label: "Connect To", allowMenu: true },
              { prop: "startPlacePrinters", label: "Printers and Faxes", allowMenu: true },
              { prop: "startPlaceAdminTools", label: "Administrative Tools", allowMenu: true },
              { prop: "startPlaceHelp", label: "Help and Support", allowMenu: false },
              { prop: "startPlaceSearch", label: "Search", allowMenu: false },
              { prop: "startPlaceRun", label: "Run...", allowMenu: false }
            ]

            Item {
              required property var modelData
              width: placesCol.width
              height: Math.max(22, showBox.implicitHeight)

              readonly property string mode: root.placeValue(modelData.prop)
              readonly property bool shown: mode !== "hidden"

              XpCheckBox {
                id: showBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                checked: parent.shown
                onToggled: root.setPlaceShown(modelData.prop, !parent.shown)
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.shown && modelData.allowMenu
                text: parent.mode === "menu" ? "Display as a menu" : "Display as a link"
                color: Theme.color("highlight", "#316AC5")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)

                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -2
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.togglePlaceStyle(modelData.prop)
                }
              }
            }
          }
        }
      }

      XpGroupBox {
        width: parent.width
        height: pinHintCol.height + 28
        title: "Pinned programs"

        Column {
          id: pinHintCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "On the XP Start menu, right-click a program (pinned list, most-frequent list, or All Programs) and choose Pin to Start menu or Unpin from Start menu. Drag pinned items to reorder."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
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
