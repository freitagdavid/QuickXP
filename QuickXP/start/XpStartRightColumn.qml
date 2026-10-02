import QtQuick
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

// Right column: special folders (Epic 2 #73); Help/Search/Run land in #74.
Item {
  id: root

  property var host: null
  property alias contentItem: content

  readonly property int columnWidth: Number(Theme.value("startPanel", "rightColumnWidth", 186))

  width: columnWidth
  implicitWidth: columnWidth

  property int openIndex: -1
  property int focusIndex: -1
  readonly property bool submenuOpen: placesSubmenu.visible

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

    Column {
      id: placeList
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: 4
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
          selected: root.focusIndex === index || root.openIndex === index
          width: placeList.width
          onActivated: {
            root.focusIndex = index
            if (modelData.kind === "folder")
              root.openFolderAt(index)
            else
              root.activateNode(modelData)
          }
          onHovered: {
            root.focusIndex = index
            if (modelData.kind === "folder")
              root.openFolderAt(index)
            else if (root.submenuOpen)
              root.closeSubmenus()
          }
        }
      }
    }
  }

  StartSubmenu {
    id: placesSubmenu
    onClosed: {
      if (root.openIndex >= 0)
        root.openIndex = -1
    }
  }
}
