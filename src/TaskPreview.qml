import QtQuick
import Quickshell

PopupWindow {
    id: preview

    property Item anchorItem: null
    property string title: ""
    property string imagePath: ""
    property bool hovered: false

    signal hoverLeft()

    visible: false
    color: Theme.color("menu", "white")
    grabFocus: false

    readonly property int pad: 4
    readonly property int maxImageWidth: 240
    readonly property int maxImageHeight: 180
    readonly property int titleHeight: 22
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

    function open() {
        if (anchorItem === null || imagePath === "")
            return
        Qt.callLater(() => {
            if (anchorItem === null || imagePath === "")
                return
            visible = true
            reposition()
        })
    }

    function dismiss() {
        visible = false
        hovered = false
        imagePath = ""
    }

    onImplicitHeightChanged: {
        if (visible)
            reposition()
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
    }
}
