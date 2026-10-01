import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
  id: menu

  property Item anchorItem: null

  visible: false
  color: Theme.color("menu", "white")
  grabFocus: false

  property bool armed: false

  readonly property int menuWidth: 160
  readonly property int menuHeight: 30

  function open() {
    if (anchorItem === null)
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
    interval: 250
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
    const pos = shellWindow.contentItem.mapFromItem(item, 0, -menu.menuHeight)
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

    Item {
      id: row
      anchors.fill: parent
      anchors.margins: 1

      readonly property bool hot: area.containsMouse

      Rectangle {
        anchors.fill: parent
        color: row.hot ? Theme.color("highlight", "#316AC5") : "transparent"
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "P<u>r</u>operties"
        textFormat: Text.RichText
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
        onClicked: {
          menu.dismiss()
          Settings.open(Config.options.lastSettingsTab || "theme")
        }
      }
    }
  }
}
