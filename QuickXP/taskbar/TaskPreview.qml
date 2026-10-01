import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
    id: preview

    property Item anchorItem: null
    property string title: ""
    property string imagePath: ""
    property bool hovered: false
    property bool closeEnabled: true

    signal hoverLeft()
    signal activated()
    signal closeClicked()

    visible: false
    color: Theme.color("menu", "white")
    grabFocus: false

    readonly property int pad: 4
    readonly property int maxImageWidth: 240
    readonly property int maxImageHeight: 180
    readonly property int titleHeight: 22
    readonly property int closeSize: 18
    readonly property real imageScale: {
        const sw = shot.sourceSize.width
        const sh = shot.sourceSize.height
        if (sw <= 0 || sh <= 0)
            return 1
        return Math.min(maxImageWidth / sw, maxImageHeight / sh, 1)
    }
    readonly property int imageWidth: {
        const sw = shot.sourceSize.width
        if (sw <= 0)
            return maxImageWidth
        return Math.max(1, Math.round(sw * imageScale))
    }
    readonly property int imageHeight: {
        const sh = shot.sourceSize.height
        if (sh <= 0)
            return 120
        return Math.max(1, Math.round(sh * imageScale))
    }

    implicitWidth: imageWidth + pad * 2
    implicitHeight: imageHeight + titleHeight + pad * 3

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    function open() {
        if (anchorItem === null || imagePath === "")
            return
        Qt.callLater(() => {
            if (preview.anchorItem === null || preview.imagePath === "")
                return
            preview.visible = true
            preview.anchor.updateAnchor()
        })
    }

    function dismiss() {
        visible = false
        hovered = false
        imagePath = ""
    }

    onImplicitHeightChanged: {
        if (visible)
            preview.anchor.updateAnchor()
    }

    anchor.window: anchorItem !== null ? anchorItem.QsWindow.window : null
    anchor.adjustment: PopupAdjustment.Slide
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.onAnchoring: {
        const item = preview.anchorItem
        if (item === null)
            return
        const shellWindow = item.QsWindow
        if (shellWindow === null || shellWindow.contentItem === null)
            return
        const pos = shellWindow.contentItem.mapFromItem(item, 0, -preview.implicitHeight - 2)
        preview.anchor.rect.x = pos.x
        preview.anchor.rect.y = pos.y
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.color("menu", "white")
        border.width: 1
        border.color: Theme.color("border", "#003C74")

        HoverHandler {
            onHoveredChanged: {
                preview.hovered = hovered
                if (!hovered)
                    preview.hoverLeft()
            }
        }

        Column {
            x: preview.pad
            y: preview.pad
            spacing: preview.pad
            width: preview.imageWidth

            Image {
                id: shot

                width: preview.imageWidth
                height: preview.imageHeight
                cache: false
                fillMode: Image.PreserveAspectFit
                source: preview.imagePath === "" ? "" : "file://" + preview.imagePath
            }

            Text {
                width: preview.imageWidth
                height: preview.titleHeight
                text: preview.title
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: Theme.color("menuText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: preview.activated()
        }

        Item {
            id: closeButton

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: preview.pad
            anchors.topMargin: preview.pad
            width: preview.closeSize
            height: preview.closeSize
            visible: preview.closeEnabled
            clip: true
            z: 1

            readonly property int frame: closeArea.containsPress ? 2 : closeArea.containsMouse ? 1 : 0

            Image {
                width: closeButton.width
                height: closeButton.height * 3
                y: -closeButton.height * closeButton.frame
                source: preview.themeImage("previewCloseImage")
                fillMode: Image.Stretch
                smooth: false
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    mouse.accepted = true
                    preview.closeClicked()
                }
            }
        }
    }
}
