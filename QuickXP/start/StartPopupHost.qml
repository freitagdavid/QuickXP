import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.controls

// Classic Start host — open/close, Esc/outside dismiss, position above Start.
// Body is classic single-column chrome; Programs cascade lands in Epic 1 #60.
// Until Epic 2 dual-column exists, this host serves all startMenu generations.
PopupWindow {
  id: host

  property Item anchorItem: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: true

  property bool armed: false

  readonly property int menuWidth: 200
  readonly property int menuMinHeight: 120

  // Classic is the only implemented layout; XP/Vista/7 reuse it until their hosts ship.
  readonly property bool useClassicChrome: true

  function open() {
    if (anchorItem === null)
      return
    armed = false
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
      contentFocus.forceActiveFocus()
    })
  }

  function close() {
    visible = false
    armed = false
    armTimer.stop()
  }

  function toggle() {
    if (visible)
      close()
    else
      open()
  }

  Timer {
    id: armTimer
    interval: 250
    onTriggered: host.armed = true
  }

  // Sit flush on the taskbar: attach to the Start button's top-left and expand up/right.
  anchor.item: anchorItem
  anchor.edges: Edges.Top | Edges.Left
  anchor.gravity: Edges.Top | Edges.Right
  anchor.adjustment: PopupAdjustment.Slide

  implicitWidth: menuWidth
  implicitHeight: Math.max(menuMinHeight, body.implicitHeight + 2)

  Rectangle {
    id: frame
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

    Item {
      id: contentFocus
      anchors.fill: parent
      anchors.margins: 1
      focus: true
      Keys.onEscapePressed: host.close()

      Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
        spacing: 0

        // Placeholder until #60 Programs cascade fills the column.
        Item {
          width: parent.width
          height: 28

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            text: "Programs"
            color: Theme.value("button", "disabledText", "#A1A192")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }
    }
  }

  XpDropdownDismiss {}
}
