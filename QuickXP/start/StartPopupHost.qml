import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP
import qs.QuickXP.controls
import qs.QuickXP.settings

// Classic Start host — open/close, Esc/outside dismiss, position above Start.
// Programs cascade via ClassicStartMenu + ProgramsCatalog; fixed shell rows via runAction.
PopupWindow {
  id: host

  property Item anchorItem: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: true

  property bool armed: false
  property string pendingSessionAction: ""

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
    const id = String(action || "")
    if (id === "documents") {
      close()
      docsProc.running = true
      return
    }
    if (id === "settings") {
      close()
      Settings.open("start")
      return
    }
    if (id === "help") {
      close()
      stubBox.title = "Help and Support"
      stubBox.open("QuickXP help will expand later. For now see docs/ROADMAP.md in the project.", false)
      return
    }
    if (id === "search") {
      close()
      stubBox.title = "Search"
      stubBox.open("Search Companion is not implemented yet.", false)
      return
    }
    if (id === "run") {
      close()
      stubBox.title = "Run"
      stubBox.open("The Run dialog lands in Epic R. Use a terminal or app launcher for now.", false)
      return
    }
    if (id === "logoff") {
      close()
      pendingSessionAction = "logoff"
      confirmBox.title = "Log Off"
      confirmBox.open("Do you want to log off?", true)
      return
    }
    if (id === "shutdown") {
      close()
      pendingSessionAction = "poweroff"
      confirmBox.title = "Shut Down"
      confirmBox.open("Do you want to turn off the computer?\n\n(Full Turn Off dialog is Epic 7.)", true)
      return
    }
    console.warn("QuickXP Start: action not implemented:", id)
  }

  function runSessionAction(action) {
    const act = String(action || "")
    if (!act)
      return
    sessionProc.command = [
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/SessionBridge.py"),
      "run",
      act
    ]
    sessionProc.running = true
  }

  Timer {
    id: armTimer
    interval: 250
    onTriggered: host.armed = true
  }

  Process {
    id: docsProc
    running: false
    command: [
      "sh", "-c",
      "xdg-open \"$(xdg-user-dir DOCUMENTS 2>/dev/null || echo \"$HOME/Documents\")\""
    ]
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP Start Documents:", data.trim())
    }
  }

  Process {
    id: sessionProc
    running: false
    command: ["true"]
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text)
          return
        try {
          const result = JSON.parse(text)
          if (!result.ok)
            console.warn("QuickXP SessionBridge:", result.error || text)
        } catch (error) {
          console.warn("QuickXP SessionBridge: bad JSON", error)
        }
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP SessionBridge:", data.trim())
    }
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

  XpMessageBox {
    id: stubBox
    title: "QuickXP"
  }

  XpMessageBox {
    id: confirmBox
    title: "QuickXP"
    onAccepted: {
      const act = host.pendingSessionAction
      host.pendingSessionAction = ""
      host.runSessionAction(act)
    }
    onRejected: host.pendingSessionAction = ""
  }
}
