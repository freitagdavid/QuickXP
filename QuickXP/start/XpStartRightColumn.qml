import QtQuick
import qs.QuickXP

// Right column shell (special folders + Help/Search/Run). Content filled by later Epic 2 tickets.
Item {
  id: root

  property var host: null
  property alias contentItem: content

  readonly property int columnWidth: Number(Theme.value("startPanel", "rightColumnWidth", 186))

  width: columnWidth
  implicitWidth: columnWidth

  BorderImage {
    id: placesSkin
    anchors.fill: parent
    source: {
      const path = Theme.image("startPanelPlacesBackgroundImage")
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
    visible: !placesSkin.visible
    color: "#D3E5FA"
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.margins: 2
  }
}
