import QtQuick
import qs.QuickXP

// Left column shell (pins + MFU + All Programs). Content filled by later Epic 2 tickets.
Item {
  id: root

  property var host: null
  property var programsNode: null
  property alias contentItem: content

  readonly property int columnWidth: Number(Theme.value("startPanel", "leftColumnWidth", 190))

  width: columnWidth
  implicitWidth: columnWidth

  BorderImage {
    id: mfuSkin
    anchors.fill: parent
    source: {
      const path = Theme.image("startPanelMfuBackgroundImage")
      return path ? ("file://" + path) : ""
    }
    border.left: 2
    border.right: 2
    border.top: 1
    border.bottom: 1
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  Rectangle {
    anchors.fill: parent
    visible: !mfuSkin.visible
    color: "#FFFFFF"
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.margins: 2
  }
}
