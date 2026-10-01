import QtQuick
import qs.QuickXP

// [button.radiobutton] RadioButton13.bmp — 8 frames: unchecked/checked × normal/hot/pressed/disabled.
Item {
  id: root

  property string text: ""
  property bool checked: false
  property bool enabled: true
  property var group: null
  signal toggled()

  implicitWidth: boxSize + 6 + label.implicitWidth
  implicitHeight: Math.max(boxSize, label.implicitHeight)

  readonly property int boxSize: 13
  readonly property int frame: {
    const base = checked ? 4 : 0
    if (!root.enabled)
      return base + 3
    if (area.containsPress)
      return base + 2
    if (area.containsMouse)
      return base + 1
    return base
  }

  function activate() {
    if (!enabled)
      return
    if (group !== null && group !== undefined && typeof group.select === "function")
      group.select(root)
    else
      checked = true
    toggled()
  }

  Item {
    id: box
    width: root.boxSize
    height: root.boxSize
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter

    Image {
      id: sheet
      visible: false
      source: {
        const path = Theme.image("radioButtonImage")
        if (path === "")
          return ""
        return path.startsWith("file:") ? path : "file://" + path
      }
    }

    Image {
      anchors.fill: parent
      visible: sheet.status === Image.Ready
      source: sheet.source
      sourceClipRect: {
        if (sheet.status !== Image.Ready)
          return Qt.rect(0, 0, 0, 0)
        const frames = Theme.value("radioButton", "frames", 8)
        const fh = sheet.sourceSize.height / frames
        return Qt.rect(0, fh * root.frame, sheet.sourceSize.width, fh)
      }
      smooth: false
      fillMode: Image.Stretch
    }

    Rectangle {
      anchors.fill: parent
      visible: sheet.status !== Image.Ready
      radius: width / 2
      color: "white"
      border.width: 1
      border.color: Theme.color("border", "#003C74")

      Rectangle {
        anchors.centerIn: parent
        width: 5
        height: 5
        radius: 2.5
        visible: root.checked
        color: "#21A121"
      }
    }
  }

  Text {
    id: label
    anchors.left: box.right
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.text
    color: root.enabled
      ? Theme.color("windowText", "black")
      : Theme.value("button", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }

  XpFocusRect {
    active: root.activeFocus
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    onClicked: root.activate()
  }

  Keys.onSpacePressed: root.activate()
  Keys.onReturnPressed: root.activate()
  activeFocusOnTab: enabled
}
