import QtQuick
import Quickshell
import qs.QuickXP

// XP dual-column Start — Luna STARTPANEL chrome (#69); content tickets fill columns.
Item {
  id: root

  property var host: null
  property var programsNode: null

  readonly property int leftW: Number(Theme.value("startPanel", "leftColumnWidth", 190))
  readonly property int rightW: Number(Theme.value("startPanel", "rightColumnWidth", 186))
  readonly property int bodyH: Number(Theme.value("startPanel", "bodyHeight", 340))
  readonly property color outerBorder: String(Theme.value("startPanel", "outerBorder", "#003C74"))

  width: leftW + rightW + 4
  implicitHeight: userBar.height + bodyH + 2

  readonly property bool submenuOpen: false

  function closeSubmenus() {}
  function resetFocus() {}
  function handleKey(event) {
    if (!event)
      return
    event.accepted = false
  }

  Rectangle {
    anchors.fill: parent
    color: root.outerBorder
  }

  Column {
    id: stack
    anchors.fill: parent
    anchors.margins: 2
    spacing: 0

    XpStartUserTile {
      id: userBar
      width: parent.width
      host: root.host
      onTileActivated: {
        if (!root.host)
          return
        // Host maps user-tile → stub until account UI exists.
      }
    }

    Row {
      id: bodyRow
      width: parent.width
      height: root.bodyH
      spacing: 0

      XpStartLeftColumn {
        id: leftCol
        height: parent.height
        host: root.host
        programsNode: root.programsNode
      }

      XpStartRightColumn {
        id: rightCol
        height: parent.height
        host: root.host
      }
    }
  }
}
