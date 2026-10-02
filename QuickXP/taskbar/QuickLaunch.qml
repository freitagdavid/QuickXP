import QtQuick
import Quickshell
import qs.QuickXP
import "../QuickLaunchModel.js" as QuickLaunchModel

Item {
  id: root

  property int iconSize: QuickLaunchModel.iconSizeForHeight(
    Config.options.taskbarHeight > 0
      ? Config.options.taskbarHeight
      : Theme.size("taskbarHeight", 30))
  readonly property int slot: QuickLaunchModel.slotWidth(iconSize)
  readonly property bool showStrip: Config.options.showQuickLaunch
    && String(GenerationPolicy.forItem("quickLaunch") || "") !== "win7"
  readonly property bool showDesktopInStrip: showStrip
    && String(GenerationPolicy.forItem("showDesktop") || "") !== "win7"

  readonly property var allIds: {
    const _ = QuickLaunchStore._revision
    return QuickLaunchStore.ids
  }

  readonly property int maxStripWidth: {
    const parentW = parent ? parent.width : 400
    return Math.max(slot * 3, Math.floor(parentW * 0.28))
  }

  readonly property var filteredIds: {
    const ids = root.allIds
    // Hide show-desktop sentinel from strip when Win7 edge owns it.
    const filtered = []
    for (let i = 0; i < ids.length; ++i) {
      if (!root.showDesktopInStrip && QuickLaunchModel.isShowDesktop(ids[i]))
        continue
      filtered.push(ids[i])
    }
    return filtered
  }

  readonly property var slices: QuickLaunchModel.visibleSlice(
    filteredIds, root.maxStripWidth, root.iconSize)

  readonly property var visibleIds: slices.visible
  readonly property var overflowIds: slices.overflow
  readonly property bool hasOverflow: overflowIds.length > 0

  readonly property int contentWidth: {
    if (!showStrip)
      return 0
    const n = visibleIds.length + (hasOverflow ? 1 : 0)
    return Math.max(slot, n * slot + 4)
  }
  width: showStrip ? Math.min(contentWidth, maxStripWidth) : 0
  implicitWidth: width
  implicitHeight: parent ? parent.height : 30
  visible: showStrip
  clip: true

  function activateId(id) {
    if (QuickLaunchModel.isShowDesktop(id)) {
      TasksService.toggleShowDesktop()
      return
    }
    const entry = AppCatalog.byId(id)
    if (entry)
      AppCatalog.launch(entry)
  }

  function themeDesktopIcon(): string {
    const path = Theme.image("quickLaunchShowDesktopImage")
    if (path && path !== "")
      return path.startsWith("file:") ? path : ("file://" + path)
    return "image://icon/user-desktop"
  }

  function iconFor(id): string {
    if (QuickLaunchModel.isShowDesktop(id))
      return root.themeDesktopIcon()
    const entry = AppCatalog.byId(id)
    return AppCatalog.iconSource(entry)
  }

  Row {
    id: row
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 2
    spacing: 0

    Repeater {
      model: root.visibleIds

      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        width: root.slot
        height: root.height

        readonly property string entryId: String(modelData || "")
        readonly property bool isDesktop: QuickLaunchModel.isShowDesktop(entryId)

        Image {
          anchors.centerIn: parent
          width: root.iconSize
          height: root.iconSize
          sourceSize.width: root.iconSize
          sourceSize.height: root.iconSize
          source: root.iconFor(cell.entryId)
          fillMode: Image.PreserveAspectFit
          smooth: true
          asynchronous: true
        }

        // XP-style separator after Show Desktop.
        Rectangle {
          visible: cell.isDesktop && cell.index === 0 && root.visibleIds.length > 1
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 1
          height: Math.max(12, root.iconSize)
          color: "#80FFFFFF"
        }

        MouseArea {
          id: cellArea
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          hoverEnabled: true
          drag.target: cell.isDesktop ? undefined : cell
          drag.axis: Drag.XAxis
          drag.threshold: 6
          onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
              if (!cell.isDesktop)
                ctxMenu.openFor(cell.entryId, cell)
              return
            }
            if (drag.active)
              return
            root.activateId(cell.entryId)
          }
          onReleased: {
            if (cell.isDesktop || !drag.active)
              return
            const from = root.allIds.indexOf(cell.entryId)
            if (from < 0)
              return
            const midX = cell.x + cell.width / 2
            let toVisible = cell.index
            for (let i = 0; i < row.children.length; ++i) {
              const child = row.children[i]
              if (!child || child === cell || child.entryId === undefined)
                continue
              if (midX >= child.x && midX < child.x + child.width) {
                toVisible = child.index
                break
              }
            }
            cell.x = 0
            const toId = root.visibleIds[toVisible]
            const to = root.allIds.indexOf(toId)
            if (to >= 0 && to !== from)
              QuickLaunchStore.move(from, to)
          }
        }
      }
    }

    Item {
      id: chevronCell
      visible: root.hasOverflow
      width: root.slot
      height: root.height

      Text {
        anchors.centerIn: parent
        text: "»"
        color: "white"
        font.pixelSize: Math.max(10, root.iconSize - 2)
        font.bold: true
      }

      MouseArea {
        anchors.fill: parent
        onClicked: overflowMenu.open()
      }
    }
  }

  // Drop target: desktop ids via text/uri-list (best-effort).
  DropArea {
    anchors.fill: parent
    keys: ["text/uri-list", "text/plain"]
    onDropped: (drop) => {
      let text = ""
      if (drop.hasText)
        text = String(drop.text || "")
      const m = text.match(/([A-Za-z0-9._-]+\.desktop)/)
      if (m)
        QuickLaunchStore.add(m[1])
      drop.acceptProposedAction()
    }
  }

  PopupWindow {
    id: ctxMenu
    property string targetId: ""
    visible: false
    color: Theme.color("menu", "white")
    grabFocus: true
    implicitWidth: 140
    implicitHeight: 28

    function openFor(id, item) {
      targetId = id
      ctxMenu.anchor.item = item
      visible = true
    }

    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    Rectangle {
      anchors.fill: parent
      color: parent.color
      border.color: Theme.color("border", "#003C74")
      border.width: 1

      Text {
        anchors.fill: parent
        anchors.margins: 6
        text: "Remove from Quick Launch"
        font.family: Theme.value("fonts", "ui", "Tahoma")
        font.pixelSize: 11
        color: Theme.color("menuText", "black")
      }

      MouseArea {
        anchors.fill: parent
        onClicked: {
          QuickLaunchStore.remove(ctxMenu.targetId)
          ctxMenu.visible = false
        }
      }
    }
  }

  PopupWindow {
    id: overflowMenu
    visible: false
    color: Theme.color("menu", "white")
    grabFocus: true
    implicitWidth: 180
    implicitHeight: Math.min(320, 8 + root.overflowIds.length * 24)

    function open() {
      anchor.item = chevronCell
      visible = true
    }

    anchor.item: chevronCell
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 4
      spacing: 0

      Repeater {
        model: root.overflowIds
        delegate: Item {
          required property var modelData
          width: parent.width
          height: 24
          readonly property string entryId: String(modelData || "")

          Image {
            id: oIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            sourceSize.width: 16
            sourceSize.height: 16
            source: root.iconFor(entryId)
            fillMode: Image.PreserveAspectFit
          }
          Text {
            anchors.left: oIcon.right
            anchors.leftMargin: 6
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: {
              if (QuickLaunchModel.isShowDesktop(entryId))
                return "Show Desktop"
              const e = AppCatalog.byId(entryId)
              return e ? String(e.name || entryId) : entryId
            }
            font.pixelSize: 11
            font.family: Theme.value("fonts", "ui", "Tahoma")
          }
          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
              if (mouse.button === Qt.RightButton) {
                if (!QuickLaunchModel.isShowDesktop(entryId))
                  QuickLaunchStore.remove(entryId)
                return
              }
              root.activateId(entryId)
              overflowMenu.visible = false
            }
          }
        }
      }
    }
  }
}
