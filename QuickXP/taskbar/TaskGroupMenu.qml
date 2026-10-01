import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
  id: menu

  property Item anchorItem: null
  property var windows: []

  signal activated(var toplevel)

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: false

  property bool armed: false

  readonly property int rowHeight: 22
  readonly property int menuWidth: 220
  readonly property int menuHeight: Math.max(rowHeight, windows.length * rowHeight) + 2

  function fileUrl(path: string): string {
    if (path === "" || path.startsWith("file:") || path.startsWith("image:") || path.startsWith("qrc:"))
      return path
    if (path.startsWith("/"))
      return "file://" + path
    return path
  }

  function iconFor(toplevel: var): string {
    let name = ""
    if (toplevel !== null && toplevel !== undefined && toplevel.appId)
      name = (() => {
        const entry = DesktopEntries.heuristicLookup(toplevel.appId)
        return entry !== null && entry.icon ? entry.icon : ""
      })()
    const path = name !== ""
      ? Quickshell.iconPath(name, "application-x-executable")
      : Quickshell.iconPath("application-x-executable")
    return fileUrl(path)
  }

  function open() {
    if (anchorItem === null || !windows || windows.length === 0)
      return
    armed = false
    Qt.callLater(() => {
      visible = true
      armTimer.restart()
    })
  }

  function dismiss() {
    visible = false
    armed = false
    armTimer.stop()
  }

  Timer {
    id: armTimer
    interval: 200
    onTriggered: menu.armed = true
  }

  anchor.window: anchorItem !== null ? anchorItem.QsWindow.window : null
  anchor.adjustment: PopupAdjustment.Slide
  anchor.gravity: Edges.Bottom | Edges.Right
  anchor.onAnchoring: {
    const item = menu.anchorItem
    if (item === null)
      return
    const shellWindow = item.QsWindow
    if (shellWindow === null || shellWindow.contentItem === null)
      return
    const pos = shellWindow.contentItem.mapFromItem(item, 0, -menu.menuHeight - 2)
    menu.anchor.rect.x = pos.x
    menu.anchor.rect.y = pos.y
    menu.anchor.rect.width = item.width
    menu.anchor.rect.height = 1
  }

  implicitWidth: menuWidth
  implicitHeight: menuHeight

  Rectangle {
    anchors.fill: parent
    color: Theme.color("menu", "white")
    border.width: 1
    border.color: Theme.color("border", "#003C74")

    HoverHandler {
      onHoveredChanged: {
        if (!menu.armed || hovered)
          return
        menu.dismiss()
      }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 1

      Repeater {
        model: menu.windows

        delegate: Item {
          id: row
          required property var modelData
          required property int index

          width: menu.menuWidth - 2
          height: menu.rowHeight

          readonly property bool hot: area.containsMouse

          Rectangle {
            anchors.fill: parent
            color: row.hot ? Theme.color("highlight", "#316AC5") : "transparent"
          }

          Image {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: menu.iconFor(row.modelData)
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            smooth: false
          }

          Text {
            anchors.left: icon.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData && row.modelData.title ? row.modelData.title : ""
            elide: Text.ElideRight
            color: row.hot
              ? Theme.color("highlightText", "white")
              : Theme.color("menuText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
              menu.activated(row.modelData)
              menu.dismiss()
            }
          }
        }
      }
    }
  }
}
