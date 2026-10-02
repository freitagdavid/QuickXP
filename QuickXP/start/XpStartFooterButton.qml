import QtQuick
import qs.QuickXP

Item {
  id: root

  property var host: null
  property string label: ""
  property string action: ""
  // 0=person, 1=key, 2=power in BLUE_STARTPANELLOGOFFBUTTONS (3×24).
  property int iconIndex: 0

  readonly property int iconSize: 24
  readonly property bool hot: area.containsMouse

  width: iconBox.width + 6 + labelText.implicitWidth
  height: Math.max(iconSize, labelText.implicitHeight)

  Item {
    id: iconBox
    width: root.iconSize
    height: root.iconSize
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    clip: true

    Image {
      id: glyph
      width: root.iconSize * 3
      height: root.iconSize
      x: -root.iconIndex * root.iconSize
      y: 0
      source: {
        const key = root.hot ? "startPanelLogoffButtonsHotImage" : "startPanelLogoffButtonsImage"
        const path = Theme.image(key)
        return path ? ("file://" + path) : ""
      }
      smooth: false
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.fill: parent
      visible: !glyph.visible
      radius: 3
      color: root.iconIndex === 2 ? "#C43C22" : "#E8A825"
    }
  }

  Text {
    id: labelText
    anchors.left: iconBox.right
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    color: root.hot ? "#FFFFFF" : "#FFFFFF"
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    style: Text.Raised
    styleColor: "#003366"
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.host && typeof root.host.runAction === "function")
        root.host.runAction(root.action)
    }
  }
}
