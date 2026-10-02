import QtQuick
import Quickshell
import qs.QuickXP

// Right-click menu for Start apps — Pin / Unpin / Remove from This List (XP).
PopupWindow {
  id: menu

  property string entryId: ""
  property bool pinned: false
  property bool showRemoveFromList: false
  property Item anchorItem: null

  signal pinRequested(string entryId)
  signal unpinRequested(string entryId)
  signal removeFromListRequested(string entryId)

  visible: false
  color: "transparent"
  grabFocus: true

  property bool armed: false

  readonly property int rowH: 22
  readonly property int menuW: 180

  function openAt(item, id, isPinned, canRemoveFromList) {
    if (!item || !id)
      return
    entryId = String(id)
    pinned = !!isPinned
    showRemoveFromList = !!canRemoveFromList
    anchorItem = item
    armed = false
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
    })
  }

  function dismiss() {
    visible = false
    armed = false
    armTimer.stop()
  }

  function choose(action) {
    const id = menu.entryId
    dismiss()
    if (!id)
      return
    if (action === "pin")
      menu.pinRequested(id)
    else if (action === "unpin")
      menu.unpinRequested(id)
    else if (action === "remove")
      menu.removeFromListRequested(id)
  }

  Timer {
    id: armTimer
    interval: 180
    onTriggered: menu.armed = true
  }

  onClosed: menu.dismiss()

  anchor.item: anchorItem
  anchor.edges: Edges.Top | Edges.Left
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.adjustment: PopupAdjustment.Slide

  implicitWidth: menuW
  implicitHeight: frame.implicitHeight

  ClassicMenuFrame {
    id: frame
    anchors.fill: parent
    implicitHeight: col.implicitHeight + 8

    HoverHandler {
      onHoveredChanged: {
        if (hovered && menu.anchorItem) {
          // Keep Start open while using the context menu.
          let p = menu.anchorItem
          while (p) {
            if (typeof p.pokeSuppress === "function") {
              p.pokeSuppress()
              break
            }
            p = p.parent
          }
        } else if (!hovered && menu.armed) {
          leaveClose.restart()
        }
        if (hovered)
          leaveClose.stop()
      }
    }

    Timer {
      id: leaveClose
      interval: 280
      onTriggered: {
        if (menu.armed)
          menu.dismiss()
      }
    }

    Column {
      id: col
      parent: frame.contentItem
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 2
      spacing: 0

      Repeater {
        model: {
          const rows = []
          if (menu.pinned)
            rows.push({ action: "unpin", label: "Unpin from Start menu" })
          else
            rows.push({ action: "pin", label: "Pin to Start menu" })
          if (menu.showRemoveFromList)
            rows.push({ action: "remove", label: "Remove from This List" })
          return rows
        }

        Item {
          required property var modelData
          width: col.width
          height: menu.rowH

          readonly property bool hot: rowArea.containsMouse

          Rectangle {
            anchors.fill: parent
            color: parent.hot ? Theme.color("classicMenuHighlight", "#0A246A") : "transparent"
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: modelData.label
            color: parent.hot ? Theme.color("highlightText", "white") : Theme.color("menuText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: menu.choose(modelData.action)
          }
        }
      }
    }
  }
}
