import QtQuick
import qs.QuickXP

// Luna top tab item: tabItemTop.bmp, imageCount=5 (normal/hot/selected/disabled/focused).
Item {
  id: root

  property string text: ""
  property bool enabled: true
  property bool selected: false
  signal clicked()

  implicitWidth: Math.max(48, label.implicitWidth + 20)
  implicitHeight: selected ? 22 : 20

  readonly property int frame: {
    if (!enabled)
      return 3
    if (selected)
      return 2
    if (area.containsMouse)
      return 1
    return 0
  }

  ThemeStrip {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: parent.height
    imageKey: "tabItemTopImage"
    frames: Theme.value("tab", "frames", 5)
    frame: root.frame
    borderLeft: Theme.value("tab", "borderLeft", 6)
    borderRight: Theme.value("tab", "borderRight", 6)
    borderTop: Theme.value("tab", "borderTop", 6)
    borderBottom: Theme.value("tab", "borderBottom", 6)
  }

  Text {
    id: label
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: root.selected ? 0 : 1
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
    onClicked: root.clicked()
  }
}
