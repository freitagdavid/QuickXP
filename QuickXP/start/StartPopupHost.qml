import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.controls

// Foundation Start host — open/close, Esc/outside dismiss, position above Start.
// Placeholder content (classic list + search); Epic 1/2 replace chrome.
PopupWindow {
  id: host

  property Item anchorItem: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: true

  property bool armed: false
  property string query: ""

  readonly property int menuWidth: 280
  readonly property int menuHeight: 360

  readonly property var apps: AppCatalog.filter(query)

  QtObject {
    id: sortGroup
    property var current: null
    function select(btn) {
      if (current && current !== btn)
        current.checked = false
      current = btn
      btn.checked = true
    }
  }

  readonly property var filteredApps: {
    const list = apps.slice()
    const band = letterFilter !== null ? letterFilter.currentIndex : 0
    let narrowed = list
    if (band === 1) {
      narrowed = list.filter(e => {
        const ch = String(e.name || "").trim().charAt(0).toUpperCase()
        return ch >= "A" && ch <= "M"
      })
    } else if (band === 2) {
      narrowed = list.filter(e => {
        const ch = String(e.name || "").trim().charAt(0).toUpperCase()
        return ch >= "N" && ch <= "Z"
      })
    }
    if (zaRadio !== null && zaRadio.checked)
      narrowed = narrowed.slice().reverse()
    return narrowed
  }

  function open() {
    if (anchorItem === null)
      return
    armed = false
    query = ""
    searchField.text = ""
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
      searchField.forceActiveFocus()
    })
  }

  function close() {
    visible = false
    armed = false
    armTimer.stop()
    tip.hide()
  }

  function toggle() {
    if (visible)
      close()
    else
      open()
  }

  function launchEntry(entry) {
    if (AppCatalog.launch(entry))
      close()
  }

  function showAbout() {
    aboutBox.open("QuickXP — XP-inspired Quickshell desktop.\nStart menu chrome lands in Epic 1/2.", false)
  }

  Timer {
    id: armTimer
    interval: 250
    onTriggered: host.armed = true
  }

  anchor.window: anchorItem !== null && anchorItem.QsWindow ? anchorItem.QsWindow.window : null
  anchor.adjustment: PopupAdjustment.Slide
  anchor.gravity: Edges.Top | Edges.Left
  anchor.onAnchoring: {
    const item = host.anchorItem
    if (item === null)
      return
    const shellWindow = item.QsWindow
    if (shellWindow === null || shellWindow.contentItem === null)
      return
    const pos = shellWindow.contentItem.mapFromItem(item, 0, -host.menuHeight)
    host.anchor.rect.x = pos.x
    host.anchor.rect.y = pos.y
    host.anchor.rect.width = Math.max(item.width, host.menuWidth)
    host.anchor.rect.height = 1
  }

  implicitWidth: menuWidth
  implicitHeight: menuHeight

  Rectangle {
    anchors.fill: parent
    color: Theme.color("menu", "white")
    border.width: 1
    border.color: Theme.color("border", "#003C74")

    HoverHandler {
      onHoveredChanged: {
        if (!host.armed || hovered)
          return
        host.close()
      }
    }

    Keys.onEscapePressed: host.close()

    Column {
      anchors.fill: parent
      anchors.margins: 6
      spacing: 6

      XpEdit {
        id: searchField
        width: parent.width
        placeholderText: "Search programs..."
        onTextEdited: host.query = text
        onAccepted: {
          if (host.filteredApps.length > 0)
            host.launchEntry(host.filteredApps[0])
        }
      }

      Row {
        id: tools
        width: parent.width
        spacing: 10
        height: Math.max(azRadio.height, zaRadio.height, letterFilter.height)

        XpRadioButton {
          id: azRadio
          text: "A–Z"
          checked: true
          group: sortGroup
          Component.onCompleted: sortGroup.current = azRadio
        }

        XpRadioButton {
          id: zaRadio
          text: "Z–A"
          group: sortGroup
        }

        XpComboBox {
          id: letterFilter
          width: 110
          model: ["All", "A–M", "N–Z"]
          currentIndex: 0
        }
      }

      XpScrollView {
        id: scroller
        width: parent.width
        height: parent.height - searchField.height - tools.height - footer.height - 24

        Column {
          width: Math.max(0, scroller.width - scroller.barWidth)
          spacing: 0

          Repeater {
            model: host.filteredApps

            delegate: Item {
              id: row
              required property var modelData
              required property int index

              width: parent.width
              height: 28

              readonly property bool hot: rowArea.containsMouse

              Rectangle {
                anchors.fill: parent
                color: row.hot ? Theme.color("highlight", "#316AC5") : "transparent"
              }

              Image {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: AppCatalog.iconSource(row.modelData)
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
              }

              Text {
                anchors.left: icon.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.name || ""
                color: row.hot
                  ? Theme.color("highlightText", "white")
                  : Theme.color("menuText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
              }

              MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: host.launchEntry(row.modelData)
                onContainsMouseChanged: {
                  if (containsMouse)
                    tip.showFor(row, row.modelData.name || "")
                  else
                    tip.hide()
                }
              }
            }
          }

          Item {
            width: parent.width
            height: 28
            visible: host.filteredApps.length === 0

            Text {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.leftMargin: 8
              text: "No matching programs"
              color: Theme.value("button", "disabledText", "#A1A192")
              font.family: Theme.value("fonts", "ui", "Tahoma")
              font.pixelSize: Theme.size("fontSize", 11)
            }
          }
        }
      }

      Item {
        id: footer
        width: parent.width
        height: 28

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 1
          color: Theme.color("border", "#003C74")
          opacity: 0.35
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          text: "About QuickXP..."
          color: aboutArea.containsMouse
            ? Theme.color("highlightText", "white")
            : Theme.color("menuText", "black")
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)

          Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            color: aboutArea.containsMouse ? Theme.color("highlight", "#316AC5") : "transparent"
          }

          MouseArea {
            id: aboutArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: host.showAbout()
          }
        }
      }
    }
  }

  XpDropdownDismiss {}

  XpToolTip {
    id: tip
  }

  XpMessageBox {
    id: aboutBox
    title: "About QuickXP"
  }
}
