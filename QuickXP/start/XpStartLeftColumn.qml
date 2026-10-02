import QtQuick
import qs.QuickXP
import "../StartMenuModel.js" as StartMenuModel

// Left column pins/MFU + All Programs — fills/borders/text from Theme.startPanel.
Item {
  id: root

  property var host: null
  property var programsNode: null
  property alias contentItem: content
  property alias allProgramsRow: allProgramsRow

  readonly property int columnWidth: Number(Theme.value("startPanel", "leftColumnWidth", 190))
  readonly property int moreProgHeight: Number(Theme.value("startPanel", "moreProgHeight", 30))
  clip: true

  width: columnWidth
  implicitWidth: columnWidth

  readonly property bool submenuOpen: programsSubmenu.visible
  property bool allProgramsHot: false

  readonly property color mfuText: String(Theme.value("startPanel", "mfuText", "#373738"))
  readonly property color mfuHot: String(Theme.value("startPanel", "mfuHot", Theme.color("highlight", "#316AC5")))
  readonly property color mfuHotText: String(Theme.value("startPanel", "mfuHotText", Theme.color("highlightText", "#FFFFFF")))

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

  function onFlyoutLeft() {
    if (host && typeof host.onFlyoutLeft === "function")
      host.onFlyoutLeft()
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

  signal allProgramsOpened()

  function openAllPrograms() {
    pokeSuppress()
    allProgramsHot = true
    allProgramsOpened()
    programsSubmenu.chrome = "xp"
    programsSubmenu.cascadeDepth = 0
    programsSubmenu.alignBottom = true
    programsSubmenu.nodes = root.programsChildren
    programsSubmenu.host = root
    programsSubmenu.openAt(allProgramsRow)
  }

  // White face — ProgList bitmap center is white (FillColorHint is only a fallback hint).
  Rectangle {
    anchors.fill: parent
    color: String(Theme.value("startPanel", "mfuFill", "#FFFFFF"))
  }

  // Left seam fallback when MFU art is missing.
  Rectangle {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 1
    color: String(Theme.value("startPanel", "outerBorder", "#003C74"))
    visible: mfuTopStrip.status !== Image.Ready
  }

  // Top decorative strip only (orange glow). Height locked to SizingMargins top so
  // the glow cannot stretch down the column when BorderImage bottom margin is 0.
  BorderImage {
    id: mfuTopStrip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Number(Theme.value("startPanel", "mfuBorderTop", 3))
    source: {
      const path = Theme.image("startPanelMfuBackgroundImage")
      return path ? ("file://" + path) : ""
    }
    border.left: Number(Theme.value("startPanel", "mfuBorderLeft", 2))
    border.right: Number(Theme.value("startPanel", "mfuBorderRight", 153))
    border.top: Number(Theme.value("startPanel", "mfuBorderTop", 3))
    border.bottom: 0
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  Item {
    id: content
    anchors.fill: parent
    anchors.leftMargin: Number(Theme.value("startPanel", "mfuContentLeft", 6))
    anchors.rightMargin: Number(Theme.value("startPanel", "mfuContentRight", 4))
    anchors.topMargin: Number(Theme.value("startPanel", "mfuContentTop", 9))
    anchors.bottomMargin: Number(Theme.value("startPanel", "mfuContentBottom", 5))

    Item {
      id: upper
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: allProgramsBar.top
      clip: true

      Flickable {
        id: scroller
        anchors.fill: parent
        contentWidth: width
        contentHeight: pinCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: pinCol
          width: scroller.width
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
              onHovered: {
                if (root.submenuOpen)
                  root.closeSubmenus()
              }
            }
          }

          Item {
            width: parent.width
            height: StartPinStore.pinRows.length ? 10 : 0
            visible: StartPinStore.pinRows.length > 0

            Image {
              id: progSep
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Math.min(sourceSize.height || 2, 4)
              source: {
                const path = Theme.image("startPanelProgramsSeparatorImage")
                return path ? ("file://" + path) : ""
              }
              fillMode: Image.Stretch
              visible: status === Image.Ready
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 4
              anchors.rightMargin: 4
              height: 1
              visible: !progSep.visible
              color: String(Theme.value("startPanel", "placesSeparator", "#7BA0D0"))
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
              onUnpinRequested: StartMfuStore.removeFromList(modelData.entryId || modelData.id)
              onHovered: {
                if (root.submenuOpen)
                  root.closeSubmenus()
              }
            }
          }
        }
      }
    }

    Item {
      id: allProgramsBar
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: root.moreProgHeight

      // Same solid face as the MFU column (theme mfuFill). MoreProgramsBackground
      // is a 4×2 glyph whose left/bottom blue pixels stretch into false chrome.

      Item {
        id: allProgramsRow
        anchors.fill: parent

        // Hover-only highlight (do not stay lit merely because the flyout is open).
        readonly property bool hot: allArea.containsMouse

        Rectangle {
          anchors.fill: parent
          anchors.margins: 1
          radius: 2
          color: allProgramsRow.hot ? root.mfuHot : "transparent"
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          text: "All Programs"
          color: allProgramsRow.hot ? root.mfuHotText : root.mfuText
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)
          font.bold: true
        }

        Image {
          anchors.right: parent.right
          anchors.rightMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 24
          source: {
            const key = allProgramsRow.hot
              ? "startPanelMoreProgArrowHotImage"
              : "startPanelMoreProgArrowImage"
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
    chrome: "xp"
    onClosed: root.allProgramsHot = false
  }
}
