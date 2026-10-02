import QtQuick
import Quickshell
import qs.QuickXP

// XP dual-column Start — sizes/colors/images from Theme.startPanel.
Item {
  id: root

  property var host: null
  property var programsNode: null

  readonly property int leftW: Number(Theme.value("startPanel", "leftColumnWidth", 190))
  readonly property int rightW: Number(Theme.value("startPanel", "rightColumnWidth", 190))
  readonly property int bodyH: Number(Theme.value("startPanel", "bodyHeight", 336))
  readonly property color outerBorder: String(Theme.value("startPanel", "outerBorder", Theme.color("border", "#003C74")))

  width: Number(Theme.value("startPanel", "width", leftW + rightW))
  // Outer 2px border margins are inside this height (Luna DefaultPaneSize 440).
  height: Number(Theme.value("startPanel", "height", 440))
  implicitHeight: height

  readonly property bool submenuOpen: rightCol.submenuOpen || leftCol.submenuOpen

  function closeSubmenus() {
    leftCol.closeSubmenus()
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

      HoverHandler {
        onHoveredChanged: {
          if (hovered && leftCol.submenuOpen)
            leftCol.closeSubmenus()
        }
      }
    }

    // Take remaining height so places/MFU never spill under the footer
    // (fixed bodyH + bar + footer exceeds the padded stack).
    Row {
      id: bodyRow
      width: parent.width
      height: Math.max(0, stack.height - userBar.height - footer.height)
      spacing: 0
      clip: true

      XpStartLeftColumn {
        id: leftCol
        height: parent.height
        host: root.host
        programsNode: root.programsNode
        onAllProgramsOpened: rightCol.closeSubmenus()
      }

      XpStartRightColumn {
        id: rightCol
        height: parent.height
        host: root.host
        onPeerHovered: leftCol.closeSubmenus()
      }
    }

    XpStartFooter {
      id: footer
      width: parent.width
      host: root.host

      HoverHandler {
        onHoveredChanged: {
          if (hovered && leftCol.submenuOpen)
            leftCol.closeSubmenus()
        }
      }
    }
  }
}
