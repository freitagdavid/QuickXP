import QtQuick
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

// Right column places — theme fill/borders/text; clipped so it never paints under the footer.
Item {
  id: root

  property var host: null
  property alias contentItem: content

  readonly property int columnWidth: Number(Theme.value("startPanel", "rightColumnWidth", 190))
  clip: true

  width: columnWidth
  implicitWidth: columnWidth

  property int openIndex: -1
  property int focusIndex: -1
  readonly property bool submenuOpen: placesSubmenu.visible

  // Emitted when the pointer is over this column so the peer (All Programs) can close.
  signal peerHovered()

  readonly property var placeRows: {
    const _ = RecentCatalog._revision
    return StartMenuModel.xpPlacesItems({
      recentNodes: RecentCatalog.recentItems,
      documents: Config.options.startPlaceDocuments,
      recentDocuments: Config.options.startPlaceRecentDocuments,
      pictures: Config.options.startPlacePictures,
      music: Config.options.startPlaceMusic,
      computer: Config.options.startPlaceComputer,
      network: Config.options.startPlaceNetwork,
      controlPanel: Config.options.startPlaceControlPanel,
      connectTo: Config.options.startPlaceConnectTo,
      printers: Config.options.startPlacePrinters,
      adminTools: Config.options.startPlaceAdminTools
    })
  }

  function pokeSuppress() {
    if (host && typeof host.pokeSuppress === "function")
      host.pokeSuppress()
  }

  function onFlyoutLeft() {
    if (host && typeof host.onFlyoutLeft === "function")
      host.onFlyoutLeft()
  }

  function closeSubmenus() {
    pokeSuppress()
    openIndex = -1
    if (placesSubmenu.visible)
      placesSubmenu.close()
  }

  function activateNode(node) {
    if (!host || !node)
      return
    if (node.kind === "folder")
      return
    if (node.kind === "action" && typeof host.runAction === "function") {
      if (node.action === "open-uri" && node.uri)
        host.openUri(node.uri)
      else
        host.runAction(node.action)
    }
  }

  function openFolderAt(index) {
    if (index < 0 || index >= placeRows.length)
      return
    const node = placeRows[index]
    if (!node || node.kind !== "folder") {
      closeSubmenus()
      return
    }
    pokeSuppress()
    if (placesSubmenu.visible && openIndex !== index)
      placesSubmenu.close()
    focusIndex = index
    openIndex = index
    const delegate = placeList.itemAt(index)
    if (!delegate)
      return
    placesSubmenu.cascadeDepth = 0
    placesSubmenu.alignBottom = false
    placesSubmenu.nodes = node.children || []
    placesSubmenu.host = root
    placesSubmenu.openAt(delegate)
  }

  // Face = theme FillColorHint (solid). PlacesBackground's orange rows are a top
  // sunburst only — full-height BorderImage stretches them into a vertical stripe.
  Rectangle {
    anchors.fill: parent
    color: String(Theme.value("startPanel", "placesFill", "#D3E5FA"))
  }

  // Top sunburst only (height locked to SizingMargins top).
  BorderImage {
    id: placesTopStrip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Number(Theme.value("startPanel", "placesBorderTop", 3))
    source: {
      const path = Theme.image("startPanelPlacesBackgroundImage")
      return path ? ("file://" + path) : ""
    }
    border.left: Number(Theme.value("startPanel", "placesBorderLeft", 172))
    border.right: Number(Theme.value("startPanel", "placesBorderRight", 7))
    border.top: Number(Theme.value("startPanel", "placesBorderTop", 3))
    border.bottom: 0
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.leftMargin: Number(Theme.value("startPanel", "placesContentLeft", 4))
    anchors.rightMargin: Number(Theme.value("startPanel", "placesContentRight", 6))
    anchors.topMargin: Number(Theme.value("startPanel", "placesContentTop", 9))
    anchors.bottomMargin: Number(Theme.value("startPanel", "placesContentBottom", 5))
    clip: true

    Flickable {
      id: scroller
      anchors.fill: parent
      contentWidth: width
      contentHeight: placeList.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      // Only interactive when the list is taller than the pane.
      interactive: contentHeight > height

      Column {
        id: placeList
        width: scroller.width
        spacing: 0

        function itemAt(index) {
          return placeRepeater.itemAt(index)
        }

        Repeater {
          id: placeRepeater
          model: root.placeRows

          XpStartPlaceItem {
            required property var modelData
            required property int index
            node: modelData
            // Sticky highlight only while this row's flyout is open; otherwise hover-only.
            selected: root.openIndex === index
            width: placeList.width
            onActivated: {
              root.focusIndex = index
              if (modelData.kind === "folder")
                root.openFolderAt(index)
              else
                root.activateNode(modelData)
            }
            onHovered: {
              root.peerHovered()
              root.focusIndex = index
              if (modelData.kind === "folder")
                root.openFolderAt(index)
              else if (root.submenuOpen)
                root.closeSubmenus()
            }
            onUnhovered: {
              if (root.focusIndex === index && root.openIndex !== index)
                root.focusIndex = -1
            }
          }
        }
      }
    }
  }

  StartSubmenu {
    id: placesSubmenu
    chrome: "xp"
    onClosed: {
      if (root.openIndex >= 0)
        root.openIndex = -1
    }
  }
}
