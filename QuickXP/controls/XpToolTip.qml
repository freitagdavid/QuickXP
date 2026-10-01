import QtQuick
import Quickshell
import qs.QuickXP

// XP info tip chrome — pale fill, 1px border (tooltip / balloon family).
PopupWindow {
  id: tip

  property Item anchorItem: null
  property string text: ""
  property int delayMs: 600

  visible: false
  color: "transparent"
  grabFocus: false

  readonly property int padX: 6
  readonly property int padY: 3

  implicitWidth: Math.ceil(label.implicitWidth + padX * 2)
  implicitHeight: Math.ceil(label.implicitHeight + padY * 2)

  function showFor(item: Item, message: string) {
    anchorItem = item
    text = message
    showTimer.restart()
  }

  function hide() {
    showTimer.stop()
    visible = false
  }

  Timer {
    id: showTimer
    interval: tip.delayMs
    onTriggered: {
      if (tip.anchorItem !== null && tip.text !== "")
        tip.visible = true
    }
  }

  anchor.window: anchorItem !== null && anchorItem.QsWindow ? anchorItem.QsWindow.window : null
  anchor.adjustment: PopupAdjustment.Slide
  anchor.gravity: Edges.Top | Edges.Left
  anchor.onAnchoring: {
    const item = tip.anchorItem
    if (item === null || item.QsWindow === null || item.QsWindow.contentItem === null)
      return
    const pos = item.QsWindow.contentItem.mapFromItem(item, 8, item.height + 4)
    tip.anchor.rect.x = pos.x
    tip.anchor.rect.y = pos.y
    tip.anchor.rect.width = 1
    tip.anchor.rect.height = 1
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.value("toolTip", "fill", "#FFFFE1")
    border.width: 1
    border.color: Theme.value("toolTip", "border", "#000000")

    Text {
      id: label
      anchors.centerIn: parent
      text: tip.text
      color: Theme.value("toolTip", "text", "#000000")
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: Theme.size("fontSize", 11)
    }
  }
}
