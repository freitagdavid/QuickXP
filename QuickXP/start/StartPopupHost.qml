import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP
import qs.QuickXP.controls
import qs.QuickXP.settings
import "StartMenuLayout.js" as StartMenuLayout

// Start popup host — Classic single-column or XP dual-column via GenerationPolicy.
PopupWindow {
  id: host

  property Item anchorItem: null

  visible: false
  color: "transparent"
  grabFocus: true

  property bool armed: false
  property bool suppressDismiss: false
  property string pendingSessionAction: ""

  readonly property int menuMinHeight: 120

  // Classic only when startMenu override/shell is classic; XP dual-column otherwise
  // (vista/win7 keep XP chrome until Epic 3 search Start).
  readonly property bool useClassicStart: StartMenuLayout.useClassic(GenerationPolicy.forItem("startMenu"))
  readonly property Item activeMenu: useClassicStart ? classicMenu : xpMenu

  function pokeSuppress() {
    suppressDismiss = true
    suppressTimer.restart()
  }

  function open() {
    if (anchorItem === null)
      return
    armed = false
    suppressDismiss = false
    activeMenu.closeSubmenus()
    Qt.callLater(() => {
      visible = true
      activeMenu.resetFocus()
      armTimer.restart()
      if (host.useClassicStart)
        classicFocus.forceActiveFocus()
      else
        xpFocus.forceActiveFocus()
    })
  }

  function close() {
    activeMenu.closeSubmenus()
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
    if (id === "open-uri") {
      // uri carried on the node; callers pass via pendingUri
      return
    }
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
    if (id === "user-tile") {
      close()
      stubBox.title = "User Accounts"
      stubBox.open("Account picture and user settings will expand later.\n\nPlace an image at ~/.face to show your picture on the Start menu.", false)
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
      confirmBox.title = "Turn Off Computer"
      confirmBox.open("Do you want to turn off the computer?\n\n(Full Turn Off dialog is Epic 7.)", true)
      return
    }
    console.warn("QuickXP Start: action not implemented:", id)
  }

  function openUri(uri) {
    const target = String(uri || "").trim()
    if (!target)
      return
    close()
    uriProc.command = ["xdg-open", target]
    uriProc.running = true
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

  Timer {
    id: suppressTimer
    interval: 120
    onTriggered: host.suppressDismiss = false
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
    id: uriProc
    running: false
    command: ["true"]
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP Start open-uri:", data.trim())
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

  implicitWidth: useClassicStart ? (classicMenu.width + 4) : xpMenu.width
  implicitHeight: useClassicStart
      ? Math.max(menuMinHeight, Math.min(520, classicMenu.implicitHeight + 4))
      : Math.max(menuMinHeight, xpMenu.implicitHeight)

  // Classic beveled frame (single-column).
  ClassicMenuFrame {
    id: classicFrame
    anchors.fill: parent
    visible: host.useClassicStart
    enabled: host.useClassicStart

    HoverHandler {
      enabled: host.useClassicStart
      onHoveredChanged: {
        if (!host.armed || hovered || host.suppressDismiss)
          return
        if (classicMenu.submenuOpen)
          return
        host.close()
      }
    }

    Item {
      id: classicFocus
      parent: classicFrame.contentItem
      anchors.fill: parent
      focus: host.useClassicStart
      Keys.onPressed: (event) => {
        if (host.useClassicStart)
          classicMenu.handleKey(event)
      }

      ClassicStartMenu {
        id: classicMenu
        anchors.left: parent.left
        anchors.top: parent.top
        host: host
        programsNode: ProgramsCatalog.programsNode
      }
    }
  }

  // XP dual-column shell (own chrome; no classic bevel).
  Item {
    id: xpFocus
    anchors.fill: parent
    visible: !host.useClassicStart
    enabled: !host.useClassicStart
    focus: !host.useClassicStart
    Keys.onPressed: (event) => {
      if (!host.useClassicStart)
        xpMenu.handleKey(event)
    }

    HoverHandler {
      enabled: !host.useClassicStart
      onHoveredChanged: {
        if (!host.armed || hovered || host.suppressDismiss)
          return
        if (xpMenu.submenuOpen)
          return
        host.close()
      }
    }

    XpStartMenu {
      id: xpMenu
      anchors.left: parent.left
      anchors.top: parent.top
      host: host
      programsNode: ProgramsCatalog.programsNode
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
