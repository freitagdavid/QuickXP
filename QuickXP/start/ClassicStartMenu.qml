import QtQuick
import Quickshell
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

Item {
  id: root

  property var host: null
  property var programsNode: null
  property string bannerText: "Windows XP Professional"
  property string userName: {
    const full = String(Quickshell.env("LOGNAME") || Quickshell.env("USER") || "").trim()
    return full || "User"
  }

  readonly property int bannerWidth: 28
  readonly property int contentWidth: 190

  width: bannerWidth + contentWidth
  implicitHeight: Math.max(banner.height, rowsCol.implicitHeight + 4)

  readonly property var rootRows: {
    const programs = programsNode && programsNode.kind === "folder"
      ? StartMenuModel.withMnemonic(programsNode, "p")
      : StartMenuModel.folderNode("programs", "Programs", "folder", [], "p")
    if (!programs.icon)
      programs.icon = "folder"
    const shell = StartMenuModel.classicShellItems()
    const session = StartMenuModel.classicSessionItems(root.userName)
    return [programs].concat(shell).concat(session)
  }

  property int openIndex: -1
  property int focusIndex: -1
  readonly property bool submenuOpen: submenu.visible

  function activateNode(node) {
    if (!host || !node)
      return
    if (node.kind === "app") {
      const entry = AppCatalog.byId(node.entryId || node.id)
      if (entry && AppCatalog.launch(entry))
        host.close()
      return
    }
    if (node.kind === "folder")
      return
    if (node.kind === "action" && typeof host.runAction === "function")
      host.runAction(node.action)
  }

  function openFolderAt(index) {
    if (index < 0 || index >= rootRows.length)
      return
    const node = rootRows[index]
    if (!node || node.kind !== "folder")
      return
    focusIndex = index
    openIndex = index
    hoverOpen.stop()
    const delegate = rowList.itemAt(index)
    if (!delegate)
      return
    submenu.nodes = node.children || []
    submenu.host = root
    submenu.openAt(delegate)
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
      openIndex = -1
      hoverOpen.stop()
      if (submenu.visible)
        submenu.close()
    }
  }

  function handleKey(event) {
    if (!event)
      return false
    if (event.key === Qt.Key_Escape) {
      if (submenu.visible) {
        submenu.close()
        openIndex = -1
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
      if (submenu.visible) {
        submenu.close()
        openIndex = -1
      }
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
      if (pending < 0)
        return
      root.focusIndex = pending
      root.openIndex = pending
      const node = root.rootRows[pending]
      if (!node || node.kind !== "folder") {
        if (submenu.visible)
          submenu.close()
        return
      }
      const delegate = rowList.itemAt(pending)
      if (!delegate)
        return
      submenu.nodes = node.children || []
      submenu.host = root
      submenu.openAt(delegate)
    }
  }

  function closeSubmenus() {
    openIndex = -1
    focusIndex = -1
    hoverOpen.stop()
    if (submenu.visible)
      submenu.close()
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
          rowHeight: 22
          node: modelData
          selected: root.focusIndex === index || (root.openIndex === index && modelData && modelData.kind === "folder")
          onActivated: {
            root.focusIndex = index
            if (modelData && modelData.kind === "folder") {
              root.openFolderAt(index)
            } else if (modelData && modelData.kind === "separator") {
              // no-op
            } else {
              root.activateNode(modelData)
            }
          }
          onHovered: {
            if (modelData && modelData.kind === "separator")
              return
            root.focusIndex = index
            hoverOpen.pending = index
            hoverOpen.restart()
          }
        }
      }
    }
  }

  StartSubmenu {
    id: submenu
    host: root
  }
}
