import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

Item {
  id: root

  property var host: null
  property var programsNode: null
  property string bannerText: distroName || "Linux"
  property string distroName: ""
  property string userName: {
    const full = String(Quickshell.env("LOGNAME") || Quickshell.env("USER") || "").trim()
    return full || "User"
  }

  readonly property int bannerWidth: 28
  readonly property int contentWidth: 190
  readonly property int itemRowHeight: 32

  width: bannerWidth + contentWidth
  implicitHeight: Math.max(banner.height, rowsCol.implicitHeight + 4)

  readonly property var rootRows: {
    const __hl = StartHighlightStore._revision
    const __pers = StartPersonalizeStore._revision
    let programs = programsNode && programsNode.kind === "folder"
      ? StartMenuModel.withMnemonic(programsNode, "p")
      : StartMenuModel.folderNode("programs", "Programs", "folder", [], "p")
    programs = StartHighlightStore.decoratePrograms(programs)
    programs = StartPersonalizeStore.decoratePrograms(programs)
    if (!programs.icon)
      programs.icon = "folder"
    const _ = RecentCatalog._revision
    const shell = StartMenuModel.classicShellItems(
      RecentCatalog.recentItems,
      RecentCatalog.favoriteItems
    )
    const session = StartMenuModel.classicSessionItems(root.userName)
    return [programs].concat(shell).concat(session)
  }

  property int openIndex: -1
  property int focusIndex: -1
  readonly property bool submenuOpen: submenu.visible

  function pokeSuppress() {
    if (host && typeof host.pokeSuppress === "function")
      host.pokeSuppress()
  }

  function onFlyoutLeft() {
    if (host && typeof host.onFlyoutLeft === "function")
      host.onFlyoutLeft()
  }

  function openAppContextMenu(anchor, entryId, showRemoveFromList) {
    const id = String(entryId || "").trim()
    if (!anchor || !id)
      return
    pokeSuppress()
    appContextMenu.openAt(anchor, id, StartPinStore.isPinned(id), !!showRemoveFromList)
  }

  function activateNode(node) {
    if (!host || !node)
      return
    if (node.kind === "app") {
      const entry = AppCatalog.byId(node.entryId || node.id)
      if (entry && AppCatalog.launch(entry)) {
        const id = node.entryId || node.id
        StartHighlightStore.markSeen(id)
        StartPersonalizeStore.bump(id)
        StartMfuStore.bump(id)
        host.close()
      }
      return
    }
    if (node.kind === "folder")
      return
    if (node.kind === "action" && node.action === "expand-personalized") {
      StartPersonalizeStore.expandFolder(node.folderId || node.id)
      return
    }
    if (node.kind === "action" && typeof host.runAction === "function") {
      if (node.action === "open-uri" && node.uri)
        host.openUri(node.uri)
      else
        host.runAction(node.action)
    }
  }

  function openFolderAt(index) {
    if (index < 0 || index >= rootRows.length)
      return
    const node = rootRows[index]
    if (!node || node.kind !== "folder") {
      closeOpenSubmenu()
      return
    }
    pokeSuppress()
    // Only one root flyout at a time.
    if (submenu.visible && openIndex !== index)
      submenu.close()
    focusIndex = index
    openIndex = index
    hoverOpen.stop()
    hoverOpen.pending = -1
    const delegate = rowList.itemAt(index)
    if (!delegate)
      return
    // First cascade: top-aligned with the row (XP Classic); nested levels flip.
    submenu.cascadeDepth = 0
    submenu.alignBottom = false
    submenu.nodes = node.children || []
    submenu.host = root
    submenu.openAt(delegate)
  }

  function closeOpenSubmenu() {
    pokeSuppress()
    openIndex = -1
    hoverOpen.stop()
    hoverOpen.pending = -1
    if (submenu.visible)
      submenu.close()
  }

  function activateFocused() {
    if (focusIndex < 0 || focusIndex >= rootRows.length)
      return
    const node = rootRows[focusIndex]
    if (!node)
      return
    if (node.kind === "folder")
      openFolderAt(focusIndex)
    else
      activateNode(node)
  }

  function moveFocus(delta) {
    focusIndex = StartMenuModel.nextSelectableIndex(rootRows, focusIndex, delta)
    if (focusIndex >= 0 && rootRows[focusIndex] && rootRows[focusIndex].kind === "folder") {
      hoverOpen.pending = focusIndex
      hoverOpen.restart()
    } else {
      closeOpenSubmenu()
    }
  }

  function handleKey(event) {
    if (!event)
      return false
    if (event.key === Qt.Key_Escape) {
      if (submenu.visible) {
        closeOpenSubmenu()
        event.accepted = true
        return true
      }
      if (host)
        host.close()
      event.accepted = true
      return true
    }
    if (event.key === Qt.Key_Up) {
      moveFocus(-1)
      event.accepted = true
      return true
    }
    if (event.key === Qt.Key_Down) {
      moveFocus(1)
      event.accepted = true
      return true
    }
    if (event.key === Qt.Key_Right || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      activateFocused()
      event.accepted = true
      return true
    }
    if (event.key === Qt.Key_Left) {
      if (submenu.visible)
        closeOpenSubmenu()
      event.accepted = true
      return true
    }
    const text = String(event.text || "")
    if (text.length === 1 && /[a-zA-Z0-9]/.test(text)) {
      const idx = StartMenuModel.mnemonicIndex(rootRows, text)
      if (idx >= 0) {
        focusIndex = idx
        activateFocused()
        event.accepted = true
        return true
      }
    }
    return false
  }

  function resetFocus() {
    focusIndex = StartMenuModel.nextSelectableIndex(rootRows, -1, 1)
    openIndex = -1
  }

  Timer {
    id: hoverOpen
    interval: 300
    property int pending: -1
    onTriggered: {
      const idx = pending
      pending = -1
      if (idx < 0)
        return
      root.focusIndex = idx
      const node = root.rootRows[idx]
      if (!node || node.kind !== "folder") {
        root.closeOpenSubmenu()
        return
      }
      root.openFolderAt(idx)
    }
  }

  function closeSubmenus() {
    focusIndex = -1
    closeOpenSubmenu()
  }

  Process {
    id: distroProc
    running: true
    command: [
      "sh", "-c",
      ". /etc/os-release 2>/dev/null; printf '%s' \"${PRETTY_NAME:-${NAME:-Linux}}\""
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (text)
          root.distroName = text
      }
    }
  }

  Row {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: 0

    ClassicStartBanner {
      id: banner
      width: root.bannerWidth
      height: Math.max(rowsCol.implicitHeight + 4, 120)
      bannerText: root.bannerText
    }

    Column {
      id: rowsCol
      width: root.contentWidth
      anchors.top: parent.top
      anchors.topMargin: 2
      spacing: 0

      Repeater {
        id: rowList
        model: root.rootRows

        delegate: StartMenuItem {
          required property var modelData
          required property int index

          width: rowsCol.width
          rowHeight: root.itemRowHeight
          node: modelData
          selected: root.openIndex === index
          onActivated: {
            root.focusIndex = index
            if (modelData && modelData.kind === "folder")
              root.openFolderAt(index)
            else if (modelData && modelData.kind === "separator")
              { /* no-op */ }
            else {
              root.closeOpenSubmenu()
              root.activateNode(modelData)
            }
          }
          onHovered: {
            if (modelData && modelData.kind === "separator")
              return
            root.focusIndex = index
            if (modelData && modelData.kind === "folder") {
              hoverOpen.pending = index
              hoverOpen.restart()
            } else {
              root.closeOpenSubmenu()
            }
          }
          onUnhovered: {
            if (root.focusIndex === index && root.openIndex !== index)
              root.focusIndex = -1
          }
          onContextMenuRequested: {
            if (!modelData || modelData.kind !== "app")
              return
            root.openAppContextMenu(this, modelData.entryId || modelData.id, false)
          }
        }
      }
    }
  }

  StartSubmenu {
    id: submenu
    host: root
    alignBottom: false
    cascadeDepth: 0
  }

  StartAppContextMenu {
    id: appContextMenu
    onPinRequested: (id) => StartPinStore.pin(id)
    onUnpinRequested: (id) => StartPinStore.unpin(id)
    onRemoveFromListRequested: (id) => StartMfuStore.removeFromList(id)
  }
}
