import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
  id: strip

  property Item anchorItem: null
  property var windows: []
  property Item taskList: null

  signal activated(var toplevel)
  signal closeClicked(var toplevel)
  signal contextMenuRequested(var toplevel, var anchorItem)
  signal hoverLeft()
  signal closedOut()

  visible: false
  color: Theme.color("menu", "white")
  // Hover strip: keep grab off so the task button retains containsMouse.
  grabFocus: false

  onClosed: strip.closedOut()

  property bool armed: false
  property bool hovered: false
  property var previews: ({})
  property var previewSerials: ({})
  property int serial: 0

  readonly property int pad: 4
  readonly property int closeSize: 18
  readonly property int cardWidth: 160
  readonly property int cardHeight: 130
  readonly property int gap: 4

  function themeImage(key: string): string {
    const path = Theme.image(key)
    if (path === "" || path.startsWith("file:"))
      return path
    return "file://" + path
  }

  function removeWindow(toplevel: var) {
    if (!windows || toplevel === null || toplevel === undefined)
      return
    const next = []
    for (let i = 0; i < windows.length; ++i) {
      const win = windows[i]
      if (win === toplevel)
        continue
      if (win && toplevel && win.kwin && toplevel.kwin
          && String(win.windowId) === String(toplevel.windowId))
        continue
      next.push(win)
    }
    windows = next
    previews = seedFromCache()
    if (next.length === 0)
      dismiss()
  }
  readonly property int stripWidth: {
    const n = windows && windows.length ? windows.length : 0
    if (n <= 0)
      return cardWidth + pad * 2
    return n * cardWidth + (n - 1) * gap + pad * 2
  }
  readonly property int stripHeight: cardHeight + pad * 2

  function cachePathFor(windowId: string): string {
    // Keep in sync with TasksBridge.preview_path / TaskList.previewCachePath.
    const safe = String(windowId).replace(/[^A-Za-z0-9._-]+/g, "_") || "unknown"
    const state = Quickshell.statePath("quickxp-tasks.json")
    const slash = state.lastIndexOf("/")
    if (slash < 0)
      return ""
    return state.substring(0, slash) + "/quickxp-preview-w-" + safe + ".png"
  }

  function seedFromCache() {
    const next = ({})
    if (!windows)
      return next
    for (let i = 0; i < windows.length; ++i) {
      const win = windows[i]
      if (!win || !win.windowId)
        continue
      const path = cachePathFor(String(win.windowId))
      if (path !== "")
        next[String(i)] = path
    }
    return next
  }

  function open() {
    if (anchorItem === null || !windows || windows.length === 0)
      return
    armed = false
    hovered = false
    // Paint cached peeks only; refresh the card under the pointer on hover.
    previews = seedFromCache()
    previewSerials = ({})
    serial += 1
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
    })
  }

  function dismiss() {
    visible = false
    armed = false
    hovered = false
    armTimer.stop()
    previews = ({})
    previewSerials = ({})
  }

  function requestCardPreview(index, windowId) {
    if (!visible || taskList === null || !windowId)
      return
    // Global serials so multi-monitor TaskLists do not collide on PREVIEW replies.
    const sid = TasksService.nextPreviewSerial()
    serial = sid
    const bag = Object.assign({}, previewSerials)
    bag[String(sid)] = index
    previewSerials = bag
    taskList.requestBridgePreview(sid, windowId)
  }

  function previewReady(sid, path) {
    if (!visible)
      return
    const index = previewSerials[String(sid)]
    if (index === undefined || index === null)
      return
    if (!path || path === "-")
      return
    const key = String(index)
    const next = Object.assign({}, previews)
    // Bridge reply means the PNG may have been rewritten in place.
    next[key] = path + "#" + Date.now()
    previews = next
  }

  Timer {
    id: armTimer
    interval: 200
    onTriggered: strip.armed = true
  }

  anchor.window: anchorItem !== null ? anchorItem.QsWindow.window : null
  anchor.adjustment: PopupAdjustment.Slide
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.onAnchoring: {
    const item = strip.anchorItem
    if (item === null)
      return
    const shellWindow = item.QsWindow
    if (shellWindow === null || shellWindow.contentItem === null)
      return
    const pos = shellWindow.contentItem.mapFromItem(item, 0, -strip.stripHeight - 2)
    strip.anchor.rect.x = pos.x
    strip.anchor.rect.y = pos.y
    strip.anchor.rect.width = item.width
    strip.anchor.rect.height = 1
  }

  implicitWidth: stripWidth
  implicitHeight: stripHeight

  Rectangle {
    anchors.fill: parent
    color: Theme.color("menu", "white")
    border.width: 1
    border.color: Theme.color("border", "#003C74")

    HoverHandler {
      onHoveredChanged: {
        strip.hovered = hovered
        if (!hovered)
          strip.hoverLeft()
      }
    }

    Row {
      x: strip.pad
      y: strip.pad
      spacing: strip.gap

      Repeater {
        model: strip.windows

        delegate: Item {
          id: card
          required property var modelData
          required property int index

          width: strip.cardWidth
          height: strip.cardHeight

          readonly property string previewPath: {
            const bag = strip.previews
            if (!bag)
              return ""
            const path = bag[String(card.index)]
            if (!path)
              return ""
            const text = String(path)
            const hash = text.lastIndexOf("#")
            return hash >= 0 ? text.substring(0, hash) : text
          }
          readonly property string previewSource: {
            const bag = strip.previews
            if (!bag)
              return ""
            const path = bag[String(card.index)]
            if (!path)
              return ""
            const text = String(path)
            const hash = text.lastIndexOf("#")
            if (hash >= 0)
              return "file://" + text.substring(0, hash) + "?" + text.substring(hash + 1)
            return "file://" + text
          }
          readonly property bool hot: area.containsMouse

          Rectangle {
            anchors.fill: parent
            color: card.hot ? Theme.color("highlight", "#316AC5") : Theme.color("window", "#ECE9D8")
            border.width: 1
            border.color: Theme.color("border", "#003C74")
          }

          Image {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            height: parent.height - 28
            fillMode: Image.PreserveAspectFit
            cache: true
            source: card.previewSource
          }

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            height: 18
            text: card.modelData && card.modelData.title ? card.modelData.title : ""
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: card.hot
              ? Theme.color("highlightText", "white")
              : Theme.color("menuText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onContainsMouseChanged: {
              if (!containsMouse)
                return
              const win = card.modelData
              if (win && win.kwin && win.windowId)
                strip.requestCardPreview(card.index, win.windowId)
            }
            onClicked: (mouse) => {
              if (mouse.button !== Qt.LeftButton)
                return
              strip.activated(card.modelData)
              strip.dismiss()
            }
            onPressed: (mouse) => {
              if (mouse.button === Qt.RightButton)
                strip.contextMenuRequested(card.modelData, card)
            }
          }

          Item {
            id: closeButton

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: strip.pad
            anchors.topMargin: strip.pad
            width: strip.closeSize
            height: strip.closeSize
            visible: card.modelData === null || card.modelData === undefined
              || card.modelData.closeable !== false
            clip: true
            z: 2

            readonly property int frame: closeArea.containsPress ? 2 : closeArea.containsMouse ? 1 : 0

            Image {
              width: closeButton.width
              height: closeButton.height * 3
              y: -closeButton.height * closeButton.frame
              source: strip.themeImage("previewCloseImage")
              fillMode: Image.Stretch
              smooth: false
            }

            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              cursorShape: Qt.PointingHandCursor
              onClicked: (mouse) => {
                mouse.accepted = true
                strip.closeClicked(card.modelData)
              }
            }
          }
        }
      }
    }
  }
}
