import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.QuickXP
import qs.QuickXP.controls
import qs.QuickXP.settings
import "StartMenuLayout.js" as StartMenuLayout
import "StartPopupPolicy.js" as StartPopupPolicy
import "../StartMenuModel.js" as StartMenuModel

// Start popup host — Classic single-column or XP dual-column via GenerationPolicy.
PopupWindow {
  id: host

  property Item anchorItem: null
  // Screen this popup belongs to (for StartService Meta / IPC targeting).
  property var screen: null
  // Disambiguate multi-monitor + PersistentProperties across hot reload.
  property string persistKey: "default"

  reloadableId: "quickxp-start-popup-" + persistKey

  visible: false
  color: "transparent"
  readonly property bool glass: GenerationPolicy.glass

  BackgroundEffect.blurRegion: glass ? startGlass : null

  Region {
    id: startGlass
    item: host.activeMenu
  }
  // grabFocus dismisses by setting visible=false (bypasses close()). Off while debugging
  // or for Meta/hotkey opens (see StartPopupPolicy.wantGrabFocus).
  grabFocus: StartPopupPolicy.wantGrabFocus(host.keepOpen, host.openedByHotkey)

  property bool armed: false
  property bool suppressDismiss: false
  // Set by StartService for Meta/hotkey opens (no grab + longer suppress / arm).
  property bool openedByHotkey: false
  // True after the pointer has entered Start chrome this open session.
  property bool everHovered: false
  property bool chromeHovered: false
  property string pendingSessionAction: ""
  // ProgramsCatalog beginOpen/endOpen pairing (also covers grabFocus auto-hide).
  property bool catalogHeld: false
  // Skip catalog release during keepOpen grabFocus hide→show flicker.
  property bool reshowGuard: false

  readonly property int menuMinHeight: 120

  // Classic only when startMenu override/shell is classic; XP dual-column otherwise.
  // Vista/7 Start search is a separate GenerationPolicy.startSearch toggle on the XP chrome.
  readonly property bool useClassicStart: StartMenuLayout.useClassic(GenerationPolicy.forItem("startMenu"))
  readonly property Item activeMenu: useClassicStart ? classicMenu : xpMenu
  readonly property bool keepOpen: StartPopupPolicy.keepOpenEnabled(Config.options.debugKeepStartMenuOpen)

  PersistentProperties {
    id: persist
    reloadableId: "quickxp-start-popup-state-" + host.persistKey
    property bool wantOpen: false
    onLoaded: host.syncDebugOpen()
  }

  function pokeSuppress() {
    suppressDismiss = true
    suppressTimer.restart()
    leaveRegionClose.stop()
  }

  // Flyout lost hover — if the pointer isn't back on Start chrome, dismiss.
  function onFlyoutLeft() {
    if (host.chromeHovered || host.suppressDismiss)
      return
    leaveRegionClose.restart()
  }

  function open() {
    if (anchorItem === null)
      return
    persist.wantOpen = true
    armed = false
    everHovered = false
    // Hotkey path: keep suppress so leave-region timers do not race Meta release.
    // Click path: clear so a fresh open is not stuck suppressed.
    if (host.openedByHotkey)
      pokeSuppress()
    else
      suppressDismiss = false
    if (!host.catalogHeld) {
      host.catalogHeld = true
      ProgramsCatalog.beginOpen()
    }
    if (!host.useClassicStart && typeof xpMenu.prepareOpen === "function")
      xpMenu.prepareOpen()
    activeMenu.closeSubmenus()
    Qt.callLater(() => {
      // grabFocus changes only apply after hide→show.
      if (host.visible && host.keepOpen && host.grabFocus) {
        host.reshowGuard = true
        host.visible = false
        Qt.callLater(() => {
          host._showNow()
          host.reshowGuard = false
        })
        return
      }
      host._showNow()
    })
  }

  function _showNow() {
    if (anchorItem === null)
      return
    visible = true
    activeMenu.resetFocus()
    armTimer.restart()
    if (host.useClassicStart) {
      classicFocus.forceActiveFocus()
      return
    }
    // Search field focuses itself in XpStartMenu.resetFocus when startSearch is on.
    if (!(xpMenu.searchEnabled))
      xpFocus.forceActiveFocus()
  }

  // force=true bypasses the Debugging "keep open" latch (Start button toggle).
  function close(force) {
    if (!StartPopupPolicy.allowClose(host.keepOpen, force))
      return
    if (force === true)
      persist.wantOpen = false
    activeMenu.closeSubmenus()
    visible = false
    armed = false
    openedByHotkey = false
    everHovered = false
    armTimer.stop()
  }

  function releaseCatalog() {
    if (!host.catalogHeld)
      return
    host.catalogHeld = false
    ProgramsCatalog.endOpen()
  }

  function toggle() {
    if (visible)
      close(true)
    else
      open()
  }

  function syncDebugOpen() {
    if (!host.keepOpen)
      return
    persist.wantOpen = true
    if (!visible)
      open()
  }

  function reclaimIfStolen() {
    if (!StartPopupPolicy.shouldReclaim(host.keepOpen, persist.wantOpen, host.visible))
      return
    reopenTimer.restart()
  }

  Component.onCompleted: Qt.callLater(syncDebugOpen)

  onKeepOpenChanged: {
    if (keepOpen) {
      persist.wantOpen = true
      if (visible) {
        visible = false
        Qt.callLater(open)
      } else {
        open()
      }
    }
  }

  onVisibleChanged: {
    if (!visible) {
      if (!host.reshowGuard)
        host.releaseCatalog()
      reclaimIfStolen()
    }
  }

  Connections {
    target: Config
    function onReadyChanged() {
      if (Config.ready)
        host.syncDebugOpen()
    }
  }

  Connections {
    target: Config.options
    function onDebugKeepStartMenuOpenChanged() {
      if (host.keepOpen)
        host.syncDebugOpen()
    }
  }

  Timer {
    id: reopenTimer
    interval: 50
    onTriggered: {
      if (host.keepOpen && persist.wantOpen && !host.visible)
        host.open()
    }
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
    if (id === "pictures") {
      close()
      openUserDir("PICTURES", "Pictures")
      return
    }
    if (id === "music") {
      close()
      openUserDir("MUSIC", "Music")
      return
    }
    if (id === "computer") {
      launchLocation("computer:///")
      return
    }
    if (id === "network") {
      launchLocation("network:///")
      return
    }
    if (id === "control-panel") {
      openSetting("theme")
      return
    }
    if (id === "settings") {
      openSetting("start")
      return
    }
    if (id === "connect-to") {
      close()
      stubBox.title = "Connect To"
      stubBox.open("Network connections UI will expand later.", false)
      return
    }
    if (id === "printers") {
      close()
      stubBox.title = "Printers and Faxes"
      stubBox.open("Printers settings will expand later.", false)
      return
    }
    if (id === "admin-tools") {
      close()
      stubBox.title = "Administrative Tools"
      stubBox.open("Administrative Tools flyout contents will expand later.", false)
      return
    }
    if (id === "recent-documents") {
      close()
      openUserDir("DOCUMENTS", "Documents")
      return
    }
    if (id === "user-tile") {
      close()
      stubBox.title = "User Accounts"
      stubBox.open("Account picture and user settings will expand later.\n\nPlace an image at ~/.face to replace the default chess picture on the Start menu.", false)
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

  function openSetting(tab) {
    close()
    Settings.open(tab)
  }

  function launchLocation(target) {
    const argv = StartMenuModel.openLocationCommand(target)
    if (!argv.length)
      return
    close()
    Quickshell.execDetached(argv)
  }

  function openUri(uri) {
    launchLocation(uri)
  }

  function openUserDir(dirName, fallback) {
    const name = String(dirName || "DOCUMENTS")
    const fb = String(fallback || "Documents")
    xdgUserDirProc.command = [
      "sh", "-c",
      "xdg-open \"$(xdg-user-dir " + name + " 2>/dev/null || echo \"$HOME/" + fb + "\")\""
    ]
    xdgUserDirProc.running = true
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
    interval: host.openedByHotkey ? 450 : 250
    onTriggered: host.armed = true
  }

  Timer {
    id: suppressTimer
    // Longer when Meta opened us — release / focus churn lasts past 120ms.
    interval: host.openedByHotkey ? 500 : 120
    onTriggered: host.suppressDismiss = false
  }

  // Pointer left Start chrome; delay so transit into a flyout PopupWindow can pokeSuppress.
  Timer {
    id: leaveRegionClose
    interval: 320
    onTriggered: {
      if (host.suppressDismiss)
        return
      if (host.activeMenu && host.activeMenu.submenuOpen)
        host.activeMenu.closeSubmenus()
      if (StartPopupPolicy.allowAutoClose(host.keepOpen))
        host.close()
    }
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
    id: xdgUserDirProc
    running: false
    command: ["true"]
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP Start user-dir:", data.trim())
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
        host.chromeHovered = hovered
        if (hovered) {
          host.everHovered = true
          leaveRegionClose.stop()
          return
        }
        if (!StartPopupPolicy.allowLeaveClose(host.everHovered, host.armed, host.suppressDismiss))
          return
        leaveRegionClose.restart()
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
        host.chromeHovered = hovered
        if (hovered) {
          host.everHovered = true
          leaveRegionClose.stop()
          return
        }
        if (!StartPopupPolicy.allowLeaveClose(host.everHovered, host.armed, host.suppressDismiss))
          return
        leaveRegionClose.restart()
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
