import QtQuick
import qs.QuickXP

// Dotted focus rectangle (VIS focus-rect). Parent should size this over the control.
Item {
  id: root

  property bool active: false
  property color ink: Theme.value("focusRect", "color", "#000000")

  visible: active
  anchors.fill: parent
  anchors.margins: 1
  z: 100

  Canvas {
    id: canvas
    anchors.fill: parent
    onPaint: {
      const ctx = getContext("2d")
      ctx.reset()
      if (!root.active || width < 2 || height < 2)
        return
      ctx.strokeStyle = root.ink
      ctx.lineWidth = 1
      ctx.setLineDash([1, 1])
      ctx.strokeRect(0.5, 0.5, width - 1, height - 1)
    }
  }

  onActiveChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onInkChanged: canvas.requestPaint()
}
