import QtQuick
import Quickshell
import qs.QuickXP

// XP dual-column Start — Luna STARTPANEL chrome; places + logoff footer.
Item {
  id: root

  property var host: null
  property var programsNode: null

  readonly property int leftW: Number(Theme.value("startPanel", "leftColumnWidth", 190))
  readonly property int rightW: Number(Theme.value("startPanel", "rightColumnWidth", 186))
  readonly property int bodyH: Number(Theme.value("startPanel", "bodyHeight", 340))
  readonly property color outerBorder: String(Theme.value("startPanel", "outerBorder", "#003C74"))

  width: leftW + rightW + 4
  implicitHeight: userBar.height + bodyH + footer.height + 2

  readonly property bool submenuOpen: rightCol.submenuOpen

  function closeSubmenus() {
    rightCol.closeSubmenus()
  }

  function resetFocus() {
    rightCol.focusIndex = -1
  }

  function handleKey(event) {
    if (!event)
      return
    event.accepted = false
  }

  function activateNode(node) {
    rightCol.activateNode(node)
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

    XpStartFooter {
      id: footer
      width: parent.width
      host: root.host
    }
  }
}
