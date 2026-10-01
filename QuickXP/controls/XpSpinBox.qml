import QtQuick
import qs.QuickXP

// Luna spin / up-down: edit buddy + Spin.Up / Spin.Down (NORMALBLUE.ini).
// Treat `value` as controlled by the parent; this control emits valueModified.
Item {
  id: root

  property int value: 0
  property int from: 0
  property int to: 100
  property int stepSize: 1
  property bool enabled: true

  signal valueModified(int value)

  readonly property int buttonWidth: Theme.value("spin", "buttonWidth", 15)
  readonly property int frames: Theme.value("spin", "frames", 4)

  implicitWidth: 72
  implicitHeight: 21

  function clamp(next) {
    return Math.max(root.from, Math.min(root.to, next))
  }

  function requestValue(next) {
    if (!root.enabled)
      return
    const clamped = root.clamp(next)
    if (clamped === root.value)
      return
    root.valueModified(clamped)
  }

  function stepBy(delta) {
    root.requestValue(root.value + delta)
  }

  function syncField() {
    if (!field.activeFocus)
      field.text = String(root.value)
  }

  function frameFor(area) {
    if (!root.enabled)
      return 3
    if (area.containsPress)
      return 2
    if (area.containsMouse)
      return 1
    return 0
  }

  onValueChanged: syncField()
  Component.onCompleted: field.text = String(root.value)

  // [edit] BorderFill — FillColor 255 255 255, BorderColor 127 157 185
  Rectangle {
    anchors.fill: parent
    color: root.enabled
      ? Theme.value("edit", "fill", "#FFFFFF")
      : "#EBEBE4"
    border.width: 1
    border.color: Theme.value("edit", "border", "#7F9DB9")
  }

  TextInput {
    id: field
    anchors.left: parent.left
    anchors.right: spinner.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: 3
    anchors.rightMargin: 1
    verticalAlignment: TextInput.AlignVCenter
    color: root.enabled
      ? Theme.color("windowText", "black")
      : Theme.value("button", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    enabled: root.enabled
    inputMethodHints: Qt.ImhDigitsOnly
    validator: IntValidator {
      bottom: root.from
      top: root.to
    }
    selectByMouse: true

    onEditingFinished: {
      const parsed = parseInt(text, 10)
      if (isNaN(parsed)) {
        text = String(root.value)
        return
      }
      root.requestValue(parsed)
      text = String(root.value)
    }
  }

  component SpinButton: Item {
    id: btn

    required property bool up
    required property string backgroundKey
    required property string glyphKey

    readonly property int frame: root.frameFor(mouse)

    ThemeStrip {
      anchors.fill: parent
      imageKey: btn.backgroundKey
      frames: root.frames
      frame: btn.frame
      borderLeft: Theme.value("spin", "borderLeft", 4)
      borderRight: Theme.value("spin", "borderRight", 4)
      borderTop: Theme.value("spin", "borderTop", 4)
      borderBottom: Theme.value("spin", "borderBottom", 4)
      smooth: false
    }

    Image {
      id: glyphSheet
      visible: false
      asynchronous: true
      source: {
        const path = Theme.image(btn.glyphKey)
        if (path === "")
          return ""
        return path.startsWith("file:") ? path : "file://" + path
      }
    }

    Image {
      anchors.centerIn: parent
      width: glyphSheet.status === Image.Ready ? glyphSheet.sourceSize.width : 0
      height: glyphSheet.status === Image.Ready && root.frames > 0
        ? glyphSheet.sourceSize.height / root.frames
        : 0
      visible: glyphSheet.status === Image.Ready
      source: glyphSheet.source
      sourceClipRect: {
        if (glyphSheet.status !== Image.Ready || root.frames <= 0)
          return Qt.rect(0, 0, 0, 0)
        const fh = glyphSheet.sourceSize.height / root.frames
        return Qt.rect(0, fh * btn.frame, glyphSheet.sourceSize.width, fh)
      }
      smooth: false
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      enabled: root.enabled
      hoverEnabled: true
      onClicked: root.stepBy(btn.up ? root.stepSize : -root.stepSize)
    }
  }

  Column {
    id: spinner
    anchors.right: parent.right
    anchors.rightMargin: 1
    anchors.top: parent.top
    anchors.topMargin: 1
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    width: root.buttonWidth
    spacing: 0

    SpinButton {
      width: parent.width
      height: Math.floor(parent.height / 2)
      up: true
      backgroundKey: "spinUpBackgroundImage"
      glyphKey: "spinUpGlyphImage"
    }

    SpinButton {
      width: parent.width
      height: Math.ceil(parent.height / 2)
      up: false
      backgroundKey: "spinDownBackgroundImage"
      glyphKey: "spinDownGlyphImage"
    }
  }

  Keys.onUpPressed: root.stepBy(root.stepSize)
  Keys.onDownPressed: root.stepBy(-root.stepSize)
}
