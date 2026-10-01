import QtQuick
import qs.QuickXP

// Vertical scrollbar over a Flickable — [ScrollBar.*] shaft / thumb / arrows (NORMALBLUE.ini).
Item {
  id: root

  default property alias contentData: content.data
  property alias contentHeight: flick.contentHeight
  property alias contentY: flick.contentY
  property alias interactive: flick.interactive
  property int barWidth: Theme.value("scrollBar", "width", 17)

  clip: true

  Flickable {
    id: flick
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: bar.visible ? bar.left : parent.right
    clip: true
    // XP scrollers never rubber-band / overscroll.
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    contentWidth: width
    contentHeight: content.height

    readonly property real maxContentY: Math.max(0, contentHeight - height)

    onContentYChanged: {
      if (contentY < 0)
        contentY = 0
      else if (contentY > maxContentY)
        contentY = maxContentY
    }

    Item {
      id: content
      width: flick.width
    }
  }

  Item {
    id: bar
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.barWidth
    visible: flick.contentHeight > flick.height + 1

    readonly property int arrowSize: root.barWidth
    readonly property real trackHeight: Math.max(0, height - arrowSize * 2)
    readonly property real ratio: flick.contentHeight > 0
      ? Math.min(1, flick.height / flick.contentHeight)
      : 1
    readonly property real thumbHeight: Math.max(arrowSize, trackHeight * ratio)
    readonly property real maxThumbY: Math.max(0, trackHeight - thumbHeight)
    readonly property real thumbY: flick.contentHeight <= flick.height
      ? 0
      : maxThumbY * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))

    function scrollBy(delta) {
      flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + delta))
    }

    function scrollToThumb(y) {
      if (maxThumbY <= 0)
        return
      const t = Math.max(0, Math.min(maxThumbY, y))
      flick.contentY = t / maxThumbY * Math.max(0, flick.contentHeight - flick.height)
    }

    Image {
      id: arrowSheet
      visible: false
      source: {
        const path = Theme.image("scrollArrowImage")
        if (path === "")
          return ""
        return path.startsWith("file:") ? path : "file://" + path
      }
    }

    Item {
      id: upBtn
      width: parent.width
      height: bar.arrowSize
      anchors.top: parent.top

      readonly property int frame: upArea.containsPress ? 2 : upArea.containsMouse ? 1 : 0

      Image {
        anchors.fill: parent
        visible: arrowSheet.status === Image.Ready
        source: arrowSheet.source
        sourceClipRect: {
          if (arrowSheet.status !== Image.Ready)
            return Qt.rect(0, 0, 0, 0)
          const frames = Theme.value("scrollBar", "arrowFrames", 16)
          const fh = arrowSheet.sourceSize.height / frames
          return Qt.rect(0, fh * upBtn.frame, arrowSheet.sourceSize.width, fh)
        }
        smooth: false
      }

      Rectangle {
        anchors.fill: parent
        visible: arrowSheet.status !== Image.Ready
        color: Theme.color("button", "#ECE9D8")
        border.width: 1
        border.color: Theme.color("border", "#003C74")
      }

      MouseArea {
        id: upArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: bar.scrollBy(-40)
      }
    }

    Item {
      id: track
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: upBtn.bottom
      anchors.bottom: downBtn.top

      Image {
        id: shaftSheet
        visible: false
        source: {
          const path = Theme.image("scrollShaftVerticalImage")
          if (path === "")
            return ""
          return path.startsWith("file:") ? path : "file://" + path
        }
      }

      Image {
        anchors.fill: parent
        visible: shaftSheet.status === Image.Ready
        source: shaftSheet.source
        sourceClipRect: {
          if (shaftSheet.status !== Image.Ready)
            return Qt.rect(0, 0, 0, 0)
          const frames = Theme.value("scrollBar", "shaftFrames", 4)
          const fh = shaftSheet.sourceSize.height / frames
          return Qt.rect(0, 0, shaftSheet.sourceSize.width, fh)
        }
        fillMode: Image.TileVertically
        smooth: false
      }

      Rectangle {
        anchors.fill: parent
        visible: shaftSheet.status !== Image.Ready
        color: "#D4D0C8"
      }

      Item {
        id: thumb
        width: parent.width
        height: bar.thumbHeight
        y: bar.thumbY

        ThemeStrip {
          anchors.fill: parent
          imageKey: "scrollThumbVerticalImage"
          frames: Theme.value("scrollBar", "thumbFrames", 4)
          frame: thumbArea.containsPress ? 2 : thumbArea.containsMouse ? 1 : 0
          borderLeft: Theme.value("scrollBar", "thumbBorderLeft", 5)
          borderRight: Theme.value("scrollBar", "thumbBorderRight", 5)
          borderTop: Theme.value("scrollBar", "thumbBorderTop", 5)
          borderBottom: Theme.value("scrollBar", "thumbBorderBottom", 5)
        }

        MouseArea {
          id: thumbArea
          anchors.fill: parent
          hoverEnabled: true
          drag.target: thumb
          drag.axis: Drag.YAxis
          drag.minimumY: 0
          drag.maximumY: bar.maxThumbY
          onPositionChanged: {
            if (pressed)
              bar.scrollToThumb(thumb.y)
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: function(mouse) {
          if (mouse.y < thumb.y)
            bar.scrollBy(-flick.height)
          else if (mouse.y > thumb.y + thumb.height)
            bar.scrollBy(flick.height)
        }
      }
    }

    Item {
      id: downBtn
      width: parent.width
      height: bar.arrowSize
      anchors.bottom: parent.bottom

      readonly property int frame: {
        const base = 4
        if (downArea.containsPress)
          return base + 2
        if (downArea.containsMouse)
          return base + 1
        return base
      }

      Image {
        anchors.fill: parent
        visible: arrowSheet.status === Image.Ready
        source: arrowSheet.source
        sourceClipRect: {
          if (arrowSheet.status !== Image.Ready)
            return Qt.rect(0, 0, 0, 0)
          const frames = Theme.value("scrollBar", "arrowFrames", 16)
          const fh = arrowSheet.sourceSize.height / frames
          return Qt.rect(0, fh * downBtn.frame, arrowSheet.sourceSize.width, fh)
        }
        smooth: false
      }

      Rectangle {
        anchors.fill: parent
        visible: arrowSheet.status !== Image.Ready
        color: Theme.color("button", "#ECE9D8")
        border.width: 1
        border.color: Theme.color("border", "#003C74")
      }

      MouseArea {
        id: downArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: bar.scrollBy(40)
      }
    }
  }
}
