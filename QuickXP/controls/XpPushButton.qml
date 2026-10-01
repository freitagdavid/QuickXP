import QtQuick
import qs.QuickXP

// Luna pushbutton: Blue\button.bmp, imageCount=5 (normal/hot/pressed/disabled/defaulted).
Item {
  id: root

  property string text: ""
  property bool enabled: true
  property bool defaulted: false
  signal clicked()

  implicitWidth: Math.max(75, label.implicitWidth + 24)
  implicitHeight: 23

  // 0 normal, 1 hot, 2 pressed, 3 disabled, 4 defaulted
  readonly property int frame: {
    if (!enabled)
      return 3
    if (area.containsPress)
      return 2
    if (area.containsMouse)
      return 1
    if (defaulted)
      return 4
    return 0
  }

  ThemeStrip {
    anchors.fill: parent
    imageKey: "buttonImage"
    frames: Theme.value("button", "frames", 5)
    frame: root.frame
    borderLeft: Theme.value("button", "borderLeft", 8)
    borderRight: Theme.value("button", "borderRight", 8)
    borderTop: Theme.value("button", "borderTop", 9)
    borderBottom: Theme.value("button", "borderBottom", 9)
  }

  Text {
    id: label
    anchors.centerIn: parent
    anchors.verticalCenterOffset: area.containsPress ? 1 : 0
    text: root.text
    color: root.enabled
      ? Theme.color("buttonText", "black")
      : Theme.value("button", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    onClicked: root.clicked()
  }
}
