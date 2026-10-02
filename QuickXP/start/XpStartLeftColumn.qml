import QtQuick
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

// Left column: pins/MFU (later) + All Programs flyout (#72).
Item {
  id: root

  property var host: null
  property var programsNode: null
  property alias contentItem: content

  readonly property int columnWidth: Number(Theme.value("startPanel", "leftColumnWidth", 190))

  width: columnWidth
  implicitWidth: columnWidth

  readonly property bool submenuOpen: programsSubmenu.visible
  property bool allProgramsHot: false

  readonly property var programsChildren: {
    const __hl = StartHighlightStore._revision
    const __pers = StartPersonalizeStore._revision
    let programs = programsNode && programsNode.kind === "folder"
      ? programsNode
      : StartMenuModel.folderNode("programs", "Programs", "folder", [], "p")
    programs = StartHighlightStore.decoratePrograms(programs)
    programs = StartPersonalizeStore.decoratePrograms(programs)
    return programs.children || []
  }

  function pokeSuppress() {
    if (host && typeof host.pokeSuppress === "function")
      host.pokeSuppress()
  }

  function closeSubmenus() {
    pokeSuppress()
    allProgramsHot = false
    if (programsSubmenu.visible)
      programsSubmenu.close()
  }

  function activateNode(node) {
    if (!host || !node)
      return
    if (node.kind === "app") {
      const entry = AppCatalog.byId(node.entryId || node.id)
      if (entry && AppCatalog.launch(entry)) {
        const id = node.entryId || node.id
        StartHighlightStore.markSeen(id)
        StartPersonalizeStore.bump(id)
        StartMfuStore.bump(id)
        host.close()
      }
      return
    }
    if (node.kind === "folder")
      return
    if (node.kind === "action" && node.action === "expand-personalized") {
      StartPersonalizeStore.expandFolder(node.folderId || node.id)
      return
    }
    if (node.kind === "action" && typeof host.runAction === "function") {
      if (node.action === "open-uri" && node.uri)
        host.openUri(node.uri)
      else
        host.runAction(node.action)
    }
  }

  function openAllPrograms() {
    pokeSuppress()
    allProgramsHot = true
    programsSubmenu.cascadeDepth = 0
    programsSubmenu.alignBottom = true
    programsSubmenu.nodes = root.programsChildren
    programsSubmenu.host = root
    programsSubmenu.openAt(allProgramsRow)
  }

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

    Item {
      id: upper
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: allProgramsBar.top

      Column {
        id: pinCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        spacing: 0

        Repeater {
          model: StartPinStore.pinRows

          XpStartAppItem {
            required property var modelData
            required property int index
            width: pinCol.width
            node: modelData
            draggable: true
            dragIndex: index
            onActivated: root.activateNode(modelData)
            onUnpinRequested: StartPinStore.unpin(modelData.entryId || modelData.id)
            onDragFinished: (fromIndex, toIndex) => StartPinStore.move(fromIndex, toIndex)
          }
        }

        Item {
          width: parent.width
          height: StartPinStore.pinRows.length ? 10 : 0
          visible: StartPinStore.pinRows.length > 0
          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            height: 1
            color: "#C4C4C4"
          }
        }

        Repeater {
          model: StartMfuStore.mfuRows

          XpStartAppItem {
            required property var modelData
            required property int index
            width: pinCol.width
            node: modelData
            draggable: false
            onActivated: root.activateNode(modelData)
            // Right-click: Remove from This List (≠ Unpin).
            onUnpinRequested: StartMfuStore.removeFromList(modelData.entryId || modelData.id)
          }
        }
      }
    }

    Item {
      id: allProgramsBar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 36

      BorderImage {
        anchors.fill: parent
        source: {
          const path = Theme.image("startPanelMoreProgBackgroundImage")
          return path ? ("file://" + path) : ""
        }
        border.left: 1
        border.right: 1
        border.top: 0
        border.bottom: 0
        horizontalTileMode: BorderImage.Stretch
        verticalTileMode: BorderImage.Stretch
        visible: status === Image.Ready
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: "#B0B0B0"
      }

      Item {
        id: allProgramsRow
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          radius: 2
          color: (root.allProgramsHot || allArea.containsMouse) ? "#316AC5" : "transparent"
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: "All Programs"
          color: (root.allProgramsHot || allArea.containsMouse) ? "#FFFFFF" : "#000000"
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)
          font.bold: true
        }

        Image {
          anchors.right: parent.right
          anchors.rightMargin: 6
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 24
          source: {
            const hot = root.allProgramsHot || allArea.containsMouse
            const key = hot ? "startPanelMoreProgArrowHotImage" : "startPanelMoreProgArrowImage"
            const path = Theme.image(key)
            return path ? ("file://" + path) : ""
          }
          smooth: false
        }

        MouseArea {
          id: allArea
          anchors.fill: parent
          hoverEnabled: true
          onEntered: root.openAllPrograms()
          onClicked: root.openAllPrograms()
        }
      }
    }
  }

  StartSubmenu {
    id: programsSubmenu
    onClosed: root.allProgramsHot = false
  }
}
