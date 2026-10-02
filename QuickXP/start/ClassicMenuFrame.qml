import QtQuick
import qs.QuickXP

// Classic Win9x/2k beveled menu chrome (raised face).
Item {
  id: root

  property color face: Theme.color("classicMenu", "#ECE9D8")
  property alias contentItem: content

  // Outer shadow edge
  Rectangle {
    anchors.fill: parent
    color: "#404040"
  }

  // Light edges (top / left)
  Rectangle {
    anchors.fill: parent
    anchors.rightMargin: 1
    anchors.bottomMargin: 1
    color: "#FFFFFF"
  }

  // Dark inner edges (bottom / right)
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: 1
    anchors.topMargin: 1
    anchors.rightMargin: 1
    anchors.bottomMargin: 1
    color: "#808080"
  }

  // Face
  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    color: root.face

    Item {
      id: content
      anchors.fill: parent
    }
  }
}
