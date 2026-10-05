import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire
import qs.QuickXP
import "TrayVolumeModel.js" as TrayVolumeModel

Item {
  id: root

  required property var node
  property var sinkNodes: []
  property bool showRoute: false
  property bool trackNode: true
  property int rowHeight: 44

  width: parent ? parent.width : 240
  height: showRoute ? rowHeight + 22 : rowHeight

  PwObjectTracker {
    // Skip destroyed/unready nodes — binding them triggers Pipewire loop warnings.
    objects: (root.trackNode && root.node && root.node.ready) ? [root.node] : []
  }

  readonly property bool ready: !!(node && node.ready && node.audio)

  Column {
    anchors.fill: parent
    spacing: 2

    Row {
      width: parent.width
      height: 20
      spacing: 6

      Image {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        sourceSize.width: 16
        sourceSize.height: 16
        source: "image://icon/" + TrayVolumeModel.streamIconName(root.node)
        fillMode: Image.PreserveAspectFit
      }

      Text {
        width: parent.width - 70
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: TrayVolumeModel.streamLabel(root.node)
        font.family: Theme.value("fonts", "ui", "Tahoma")
        font.pixelSize: 11
        color: Theme.color("menuText", "#000000")
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        text: root.ready ? (root.node.audio.muted ? "Mute" : (TrayVolumeModel.volumePercent(root.node.audio.volume) + "%")) : ""
        font.family: Theme.value("fonts", "ui", "Tahoma")
        font.pixelSize: 10
        color: Theme.color("menuText", "#000000")

        MouseArea {
          anchors.fill: parent
          onClicked: {
            if (root.ready)
              root.node.audio.muted = !root.node.audio.muted
          }
        }
      }
    }

    Slider {
      id: volSlider
      width: parent.width
      height: 18
      from: 0
      to: 1
      enabled: root.ready
      value: root.ready ? root.node.audio.volume : 0
      onMoved: {
        if (root.ready)
          root.node.audio.volume = value
      }
    }

    Column {
      visible: root.showRoute && root.sinkNodes.length > 1
      width: parent.width
      spacing: 1

      Text {
        text: "Move to:"
        font.pixelSize: 10
        font.family: Theme.value("fonts", "ui", "Tahoma")
        color: Theme.color("menuText", "#000000")
      }

      Repeater {
        model: root.sinkNodes
        delegate: Text {
          required property var modelData
          width: parent.width
          text: "  " + TrayVolumeModel.nodeLabel(modelData)
          font.pixelSize: 10
          font.underline: true
          font.family: Theme.value("fonts", "ui", "Tahoma")
          color: "#003399"
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.routeRequested(modelData)
          }
        }
      }
    }
  }

  signal routeRequested(var sinkNode)
}
