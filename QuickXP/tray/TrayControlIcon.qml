import QtQuick
import Qt5Compat.GraphicalEffects
import qs.QuickXP

Item {
  id: root

  property string iconSource: ""
  property string tipTitle: ""
  property string tipBody: ""
  property bool active: true
  property var trayRoot: null

  signal activated()
  signal middleActivated()
  signal wheelDelta(int steps)

  readonly property int iconSize: trayRoot ? trayRoot.iconSize : 16

  visible: active
  width: active ? iconSize + 2 : 0
  height: parent ? parent.height : iconSize
  clip: true

  Item {
    anchors.centerIn: parent
    width: root.iconSize + 1
    height: root.iconSize + 1
    visible: root.active

    ColorOverlay {
      x: 1
      y: 1
      width: root.iconSize
      height: root.iconSize
      source: glyph
      color: "black"
      visible: glyph.status === Image.Ready
    }

    Image {
      id: glyph
      width: root.iconSize
      height: root.iconSize
      source: root.iconSource
      sourceSize.width: root.iconSize
      sourceSize.height: root.iconSize
      fillMode: Image.PreserveAspectFit
      asynchronous: false
      smooth: false
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onContainsMouseChanged: {
      if (!root.trayRoot)
        return
      if (containsMouse)
        root.trayRoot.showTip(root, root.tipTitle, root.tipBody)
      else
        root.trayRoot.hideTip(root)
    }
    onClicked: (mouse) => {
      if (root.trayRoot) {
        root.trayRoot.hideTip(null)
        if (typeof root.trayRoot.dismissControlPopups === "function")
          root.trayRoot.dismissControlPopups()
      }
      if (mouse.button === Qt.MiddleButton)
        root.middleActivated()
      else
        root.activated()
    }
    onWheel: (wheel) => {
      const dy = wheel.angleDelta.y
      if (dy === 0)
        return
      root.wheelDelta(dy > 0 ? 1 : -1)
    }
  }
}
