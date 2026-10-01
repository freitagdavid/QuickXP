import QtQuick
import qs.QuickXP

// Etched group box chrome (Luna groupbox / SysMetrics edge colors).
Item {
  id: root

  property string title: ""
  default property alias contentData: body.data

  implicitHeight: titleText.implicitHeight + body.implicitHeight + 16
  implicitWidth: Math.max(titleText.implicitWidth + 16, 120)

  Text {
    id: titleText
    x: 8
    y: 0
    z: 2
    text: root.title
    color: Theme.color("highlight", "#316AC5")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }

  Rectangle {
    id: titleCover
    z: 1
    x: titleText.x - 2
    y: Math.round(titleText.height / 2) - 1
    width: titleText.implicitWidth + 4
    height: 3
    color: Theme.color("window", "#ECE9D8")
    visible: root.title !== ""
  }

  Rectangle {
    id: frame
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: Math.round(titleText.height / 2)
    anchors.bottom: parent.bottom
    color: "transparent"
    border.width: 1
    border.color: Theme.value("groupBox", "edgeShadow", "#ACA899")
    radius: 0

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      color: "transparent"
      border.width: 1
      border.color: Theme.value("groupBox", "edgeHighlight", "#FFFFFF")
    }
  }

  Item {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: titleText.height + 4
    anchors.bottom: parent.bottom
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.bottomMargin: 8
  }
}
