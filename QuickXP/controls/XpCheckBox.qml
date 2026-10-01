import QtQuick
import qs.QuickXP

// Luna checkbox: CheckBox13.bmp, 12 vertical frames (unchecked/checked/mixed × normal/hot/pressed/disabled).
Item {
  id: root

  property string text: ""
  property bool checked: false
  property bool enabled: true
  signal toggled()

  implicitWidth: boxSize + 6 + label.implicitWidth
  implicitHeight: Math.max(boxSize, label.implicitHeight)

  readonly property int boxSize: 13
  // Base: 0 unchecked, 4 checked, 8 mixed. Offset +0..3 for normal/hot/pressed/disabled.
  readonly property int frame: {
    const base = checked ? 4 : 0
    if (!enabled)
      return base + 3
    if (area.containsPress)
      return base + 2
    if (area.containsMouse)
      return base + 1
    return base
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
        const path = Theme.image("checkBoxImage")
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
        const frames = Theme.value("checkBox", "frames", 12)
        const fh = sheet.sourceSize.height / frames
        return Qt.rect(0, fh * root.frame, sheet.sourceSize.width, fh)
      }
      smooth: false
      fillMode: Image.Stretch
    }

    Rectangle {
      anchors.fill: parent
      visible: sheet.status !== Image.Ready
      color: "white"
      border.width: 1
      border.color: Theme.color("border", "#003C74")

      Text {
        anchors.centerIn: parent
        visible: root.checked
        text: "✓"
        font.pixelSize: 11
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

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    onClicked: root.toggled()
  }
}
