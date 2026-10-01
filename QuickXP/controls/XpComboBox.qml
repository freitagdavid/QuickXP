import QtQuick
import Quickshell
import qs.QuickXP

// [Combobox] BorderFill field + [Combobox.DropDownButton] ComboButton.bmp (4 frames).
Item {
  id: root

  property var model: []
  property int currentIndex: -1
  property bool enabled: true
  property string textRole: ""
  signal activated(int index)

  implicitWidth: 140
  implicitHeight: 21

  readonly property int buttonWidth: Theme.value("combo", "buttonWidth", 17)
  readonly property string currentText: {
    if (currentIndex < 0 || currentIndex >= count)
      return ""
    return textAt(currentIndex)
  }
  readonly property int count: model !== undefined && model !== null
    ? (model.count !== undefined ? model.count : model.length)
    : 0

  function textAt(index) {
    if (index < 0 || index >= count)
      return ""
    const item = model.get !== undefined ? model.get(index) : model[index]
    if (item === undefined || item === null)
      return ""
    if (typeof item === "string" || typeof item === "number")
      return String(item)
    if (textRole !== "" && item[textRole] !== undefined)
      return String(item[textRole])
    if (item.text !== undefined)
      return String(item.text)
    if (item.label !== undefined)
      return String(item.label)
    return String(item)
  }

  function closePopup() {
    popup.visible = false
  }

  function select(index) {
    if (!enabled || index < 0 || index >= count)
      return
    currentIndex = index
    closePopup()
    activated(index)
  }

  function openPopup() {
    DropdownGate.claim(root)
    popup.visible = true
  }

  function togglePopup() {
    if (!enabled)
      return
    if (popup.visible)
      closePopup()
    else
      openPopup()
  }

  Component.onDestruction: DropdownGate.release(root)

  readonly property int buttonFrame: {
    if (!enabled)
      return 3
    if (dropArea.containsPress)
      return 2
    if (dropArea.containsMouse || popup.visible)
      return 1
    return 0
  }

  Rectangle {
    anchors.fill: parent
    color: root.enabled
      ? Theme.value("edit", "fill", "#FFFFFF")
      : Theme.value("edit", "disabledFill", "#EBEBE4")
    border.width: 1
    border.color: Theme.value("edit", "border", "#7F9DB9")
  }

  Text {
    anchors.left: parent.left
    anchors.right: dropButton.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: 4
    anchors.rightMargin: 2
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    text: root.currentText
    color: root.enabled
      ? Theme.color("windowText", "black")
      : Theme.value("button", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }

  Item {
    id: dropButton
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.margins: 1
    width: root.buttonWidth

    ThemeStrip {
      anchors.fill: parent
      imageKey: "comboButtonImage"
      frames: Theme.value("combo", "frames", 4)
      frame: root.buttonFrame
      borderLeft: Theme.value("combo", "borderLeft", 3)
      borderRight: Theme.value("combo", "borderRight", 3)
      borderTop: Theme.value("combo", "borderTop", 3)
      borderBottom: Theme.value("combo", "borderBottom", 3)
    }

    Item {
      id: glyphClip
      anchors.centerIn: parent
      readonly property int frames: Theme.value("combo", "frames", 4)
      readonly property real fh: glyphSheet.status === Image.Ready
        ? glyphSheet.sourceSize.height / frames
        : 0
      width: glyphSheet.status === Image.Ready ? glyphSheet.sourceSize.width : 0
      height: fh
      clip: true
      visible: glyphSheet.status === Image.Ready

      Image {
        id: glyphSheet
        width: sourceSize.width
        height: sourceSize.height
        y: -glyphClip.fh * Math.min(glyphClip.frames - 1, root.buttonFrame)
        smooth: false
        source: {
          const path = Theme.image("comboButtonGlyphImage")
          if (path === "")
            return ""
          return path.startsWith("file:") ? path : "file://" + path
        }
      }
    }

    MouseArea {
      id: dropArea
      anchors.fill: parent
      enabled: root.enabled
      hoverEnabled: true
      onClicked: root.togglePopup()
    }
  }

  MouseArea {
    anchors.fill: parent
    anchors.rightMargin: root.buttonWidth
    enabled: root.enabled
    onClicked: root.togglePopup()
  }

  XpFocusRect {
    active: root.activeFocus
  }

  PopupWindow {
    id: popup
    visible: false
    color: Theme.color("menu", "white")
    grabFocus: true
    implicitWidth: Math.max(root.width, 120)
    implicitHeight: Math.min(160, Math.max(24, root.count * 20 + 2))

    anchor.item: root
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right

    onVisibleChanged: {
      if (visible)
        DropdownGate.claim(root)
      else
        DropdownGate.release(root)
    }

    onClosed: root.closePopup()

    Rectangle {
      anchors.fill: parent
      color: Theme.color("menu", "white")
      border.width: 1
      border.color: Theme.value("edit", "border", "#7F9DB9")

      ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 1
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        model: root.count
        delegate: Item {
          width: list.width
          height: 20
          readonly property int row: index
          readonly property bool hot: rowArea.containsMouse

          Rectangle {
            anchors.fill: parent
            color: hot ? Theme.color("highlight", "#316AC5") : "transparent"
          }

          Text {
            anchors.fill: parent
            anchors.leftMargin: 4
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: root.textAt(row)
            color: hot
              ? Theme.color("highlightText", "white")
              : Theme.color("menuText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.select(row)
          }
        }
      }
    }
  }

  Keys.onDownPressed: togglePopup()
  Keys.onSpacePressed: togglePopup()
  activeFocusOnTab: enabled
}
