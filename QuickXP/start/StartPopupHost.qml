import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.controls

// Classic Start host — open/close, Esc/outside dismiss, position above Start.
// Programs cascade via ClassicStartMenu + ProgramsCatalog (#60).
PopupWindow {
  id: host

  property Item anchorItem: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: true

  property bool armed: false

  readonly property int menuWidth: 200
  readonly property int menuMinHeight: 120

  function open() {
    if (anchorItem === null)
      return
    armed = false
    classicMenu.closeSubmenus()
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
      contentFocus.forceActiveFocus()
    })
  }

  function close() {
    classicMenu.closeSubmenus()
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

  function runAction(action) {
    // Shell / session actions arrive in later Epic 1 tickets.
    console.warn("QuickXP Start: action not implemented:", action)
  }

  Timer {
    id: armTimer
    interval: 250
    onTriggered: host.armed = true
  }

  anchor.item: anchorItem
  anchor.edges: Edges.Top | Edges.Left
  anchor.gravity: Edges.Top | Edges.Right
  anchor.adjustment: PopupAdjustment.Slide

  implicitWidth: menuWidth
  implicitHeight: Math.max(menuMinHeight, Math.min(480, body.implicitHeight + 4))

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
        // Keep root open while a Programs flyout is showing.
        if (classicMenu.submenuOpen)
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

        ClassicStartMenu {
          id: classicMenu
          width: parent.width
          host: host
          programsNode: ProgramsCatalog.programsNode
        }
      }
    }
  }

  XpDropdownDismiss {}
}
