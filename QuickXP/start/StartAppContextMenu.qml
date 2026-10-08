import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP

// Right-click menu for Start apps — pin, open location, copy path, properties.
Item {
  id: root

  property string entryId: ""
  property bool pinned: false
  property bool showRemoveFromList: false
  property Item anchorItem: null

  property int locateSerial: 0
  property var located: null
  property string binaryPath: ""
  property bool binaryExists: false
  property bool desktopFound: false

  signal pinRequested(string entryId)
  signal unpinRequested(string entryId)
  signal removeFromListRequested(string entryId)

  function openAt(item, id, isPinned, canRemoveFromList) {
    if (!item || !id)
      return
    entryId = String(id)
    pinned = !!isPinned
    showRemoveFromList = !!canRemoveFromList
    anchorItem = item
    located = null
    binaryPath = ""
    binaryExists = false
    desktopFound = false
    locateSerial += 1
    menu.armed = false
    locateProc.running = false
    locateProc.exec([
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/DesktopFile.py"),
      "locate",
      entryId,
      String(locateSerial)
    ])
    Qt.callLater(() => {
      menu.visible = true
      armTimer.restart()
    })
  }

  function dismiss() {
    menu.visible = false
    menu.armed = false
    armTimer.stop()
  }

  function parentDirectory(path) {
    const text = String(path || "")
    const slash = text.lastIndexOf("/")
    if (slash <= 0)
      return ""
    return text.substring(0, slash)
  }

  function choose(action) {
    const id = root.entryId
    if (!id || action === "sep")
      return
    if (action === "open") {
      if (!root.binaryExists)
        return
      const dir = root.parentDirectory(root.binaryPath)
      root.dismiss()
      if (dir)
        Quickshell.execDetached(["xdg-open", dir])
      return
    }
    if (action === "copy") {
      if (!root.binaryExists)
        return
      Quickshell.clipboardText = root.binaryPath
      root.dismiss()
      return
    }
    if (action === "properties") {
      if (!root.desktopFound || root.located === null)
        return
      const info = root.located
      root.dismiss()
      properties.openWith(id, info)
      return
    }
    root.dismiss()
    if (action === "pin")
      root.pinRequested(id)
    else if (action === "unpin")
      root.unpinRequested(id)
    else if (action === "remove")
      root.removeFromListRequested(id)
  }

  function saveFields(id, fields) {
    if (!id || !fields)
      return
    saveProc.running = false
    saveProc.exec([
      "/usr/bin/python3",
      Quickshell.shellPath("QuickXP/services/DesktopFile.py"),
      "save",
      String(id),
      JSON.stringify(fields)
    ])
  }

  Process {
    id: locateProc
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text)
          return
        let reply = null
        try {
          reply = JSON.parse(text)
        } catch (error) {
          console.warn("QuickXP shortcut locate: bad JSON", error)
          return
        }
        if (!reply || String(reply.token || "") !== String(root.locateSerial))
          return
        root.located = reply.ok ? reply : null
        root.desktopFound = !!reply.ok
        root.binaryPath = reply.binary ? String(reply.binary) : ""
        root.binaryExists = !!reply.binaryExists && root.binaryPath !== ""
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (text)
          console.warn("QuickXP shortcut locate:", text)
      }
    }
  }

  Process {
    id: saveProc
    stdout: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (!text)
          return
        try {
          const reply = JSON.parse(text)
          if (!reply.ok)
            console.warn("QuickXP shortcut properties:", reply.error || "save failed")
        } catch (error) {
          console.warn("QuickXP shortcut properties: bad save JSON", error)
        }
      }
    }
    stderr: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim()
        if (text)
          console.warn("QuickXP shortcut properties:", text)
      }
    }
  }

  StartShortcutProperties {
    id: properties
    onSaveRequested: (id, fields) => root.saveFields(id, fields)
  }

  Timer {
    id: armTimer
    interval: 180
    onTriggered: menu.armed = true
  }

  PopupWindow {
    id: menu

    visible: false
    color: "transparent"
    grabFocus: true

    property bool armed: false

    readonly property int rowH: 22
    readonly property int menuW: 210

    onClosed: root.dismiss()

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Slide

    implicitWidth: menuW
    implicitHeight: frame.implicitHeight

    ClassicMenuFrame {
      id: frame
      anchors.fill: parent
      implicitHeight: col.implicitHeight + 8

      HoverHandler {
        onHoveredChanged: {
          if (hovered && root.anchorItem) {
            let p = root.anchorItem
            while (p) {
              if (typeof p.pokeSuppress === "function") {
                p.pokeSuppress()
                break
              }
              p = p.parent
            }
          } else if (!hovered && menu.armed) {
            leaveClose.restart()
          }
          if (hovered)
            leaveClose.stop()
        }
      }

      Timer {
        id: leaveClose
        interval: 280
        onTriggered: {
          if (menu.armed)
            root.dismiss()
        }
      }

      Column {
        id: col
        parent: frame.contentItem
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
        spacing: 0

        Repeater {
          model: {
            const rows = []
            if (root.pinned)
              rows.push({ action: "unpin", label: "Unpin from Start menu", enabled: true })
            else
              rows.push({ action: "pin", label: "Pin to Start menu", enabled: true })
            if (root.showRemoveFromList)
              rows.push({ action: "remove", label: "Remove from This List", enabled: true })
            rows.push({ action: "sep", label: "", enabled: true })
            rows.push({
              action: "open",
              label: "Open file location",
              enabled: root.binaryExists
            })
            rows.push({
              action: "copy",
              label: "Copy location",
              enabled: root.binaryExists
            })
            rows.push({
              action: "properties",
              label: "Properties",
              enabled: root.desktopFound
            })
            return rows
          }

          Item {
            required property var modelData
            width: col.width
            height: modelData.action === "sep" ? 7 : menu.rowH

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 4
              anchors.rightMargin: 4
              height: 1
              visible: modelData.action === "sep"
              color: Theme.color("border", "#ACA899")
            }

            Rectangle {
              anchors.fill: parent
              visible: modelData.action !== "sep"
              color: rowArea.containsMouse && modelData.enabled
                ? Theme.color("classicMenuHighlight", "#0A246A")
                : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              visible: modelData.action !== "sep"
              elide: Text.ElideRight
              text: modelData.label
              color: {
                if (!modelData.enabled)
                  return Theme.value("button", "disabledText", "#A1A192")
                if (rowArea.containsMouse)
                  return Theme.color("highlightText", "white")
                return Theme.color("menuText", "black")
              }
              font.family: Theme.value("fonts", "ui", "Tahoma")
              font.pixelSize: Theme.size("fontSize", 11)
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              enabled: modelData.action !== "sep" && modelData.enabled
              hoverEnabled: true
              onClicked: root.choose(modelData.action)
            }
          }
        }
      }
    }
  }
}
