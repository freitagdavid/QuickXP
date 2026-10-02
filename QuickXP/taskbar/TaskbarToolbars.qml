import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.QuickXP
import "../ToolbarModel.js" as ToolbarModel
import "../QuickLaunchModel.js" as QuickLaunchModel

Item {
  id: root

  readonly property int iconSize: QuickLaunchModel.iconSizeForHeight(
    Config.options.taskbarHeight > 0
      ? Config.options.taskbarHeight
      : Theme.size("taskbarHeight", 30))

  readonly property var bands: {
    const _ = Config.options.taskbarToolbars
    return ToolbarModel.parseToolbars(_)
  }

  readonly property var visibleBands: {
    const list = root.bands
    const out = []
    for (let i = 0; i < list.length; ++i) {
      if (list[i].visible)
        out.push(list[i])
    }
    return out
  }

  implicitWidth: {
    let w = 0
    const list = root.visibleBands
    for (let i = 0; i < list.length; ++i)
      w += list[i].width + 4
    return w
  }
  implicitHeight: parent ? parent.height : 30
  visible: visibleBands.length > 0
  width: visible ? implicitWidth : 0
  clip: true

  function openPath(path) {
    const p = String(path || "")
    if (!p)
      return
    Quickshell.execDetached(["xdg-open", p])
  }

  Row {
    anchors.fill: parent
    spacing: 4

    Repeater {
      model: root.visibleBands

      delegate: Item {
        id: band
        required property var modelData
        width: modelData.width
        height: parent.height

        FolderListModel {
          id: folderModel
          folder: modelData.path ? ("file://" + modelData.path) : ""
          showDirs: true
          showDotAndDotDot: false
          sortField: FolderListModel.Name
        }

        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.width: 1
          border.color: "#40FFFFFF"
        }

        Text {
          id: titleLabel
          visible: modelData.showTitle
          anchors.left: parent.left
          anchors.top: parent.top
          anchors.leftMargin: 4
          anchors.topMargin: 1
          text: modelData.id
          color: "white"
          font.pixelSize: 9
          font.family: Theme.value("fonts", "ui", "Tahoma")
        }

        Row {
          id: iconRow
          anchors.left: parent.left
          anchors.right: gripper.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 4
          anchors.rightMargin: 2
          spacing: 2
          clip: true

          Repeater {
            model: folderModel
            delegate: Item {
              required property string filePath
              required property string fileName
              required property bool fileIsDir
              width: root.iconSize + (modelData.showText ? 48 : 0)
              height: band.height
              visible: x + width <= iconRow.width

              Image {
                id: fIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconSize
                height: root.iconSize
                sourceSize.width: root.iconSize
                sourceSize.height: root.iconSize
                source: fileIsDir ? "image://icon/folder" : "image://icon/text-x-generic"
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }
              Text {
                visible: modelData.showText
                anchors.left: fIcon.right
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                elide: Text.ElideRight
                text: fileName
                color: "white"
                font.pixelSize: 10
                font.family: Theme.value("fonts", "ui", "Tahoma")
              }
              MouseArea {
                anchors.fill: parent
                onClicked: root.openPath(filePath)
              }
            }
          }
        }

        Rectangle {
          id: gripper
          visible: !Config.options.taskbarLocked
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          width: 4
          color: "#60FFFFFF"

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeHorCursor
            property real pressGlobalX: 0
            property real startW: 0
            onPressed: (mouse) => {
              pressGlobalX = mapToItem(null, mouse.x, 0).x
              startW = modelData.width
            }
            onPositionChanged: (mouse) => {
              if (!pressed)
                return
              const gx = mapToItem(null, mouse.x, 0).x
              Config.options.taskbarToolbars = ToolbarModel.setWidth(
                Config.options.taskbarToolbars, modelData.id, startW + (gx - pressGlobalX))
            }
          }
        }
      }
    }
  }
}
