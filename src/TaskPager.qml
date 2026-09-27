import QtQuick

// Up/down page arrows for the task band. Luna uses the 16-frame scrollbar
// arrow strip: 0-3 up (normal, hot, pressed, disabled), 4-7 down.
Item {
    id: root

    property bool upEnabled: false
    property bool downEnabled: false

    signal upClicked()
    signal downClicked()

    implicitWidth: height > 0 ? height / 2 : 0

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    component ArrowButton: Item {
        id: button

        property bool pointUp: true
        property bool arrowEnabled: true
        signal clicked()

        readonly property int frames: 16
        readonly property int frame: {
            const base = pointUp ? 0 : 4
            if (!arrowEnabled)
                return base + 3
            if (area.containsPress)
                return base + 2
            if (area.containsMouse)
                return base + 1
            return base
        }
        readonly property bool useSprite: face.status === Image.Ready
        readonly property bool useGlyph: glyph.status === Image.Ready
        readonly property color chevronColor: arrowEnabled
            ? Theme.color("taskbarText", "white")
            : Qt.rgba(1, 1, 1, 0.35)

        Rectangle {
            visible: !button.useSprite
            anchors.fill: parent
            color: area.containsPress && button.arrowEnabled
                ? Qt.darker(Theme.color("taskbar", "#245EDC"), 1.25)
                : Theme.color("taskbar", "#245EDC")
            border.width: 1
            border.color: Theme.color("border", "#0C3E9E")
        }

        Canvas {
            visible: !button.useSprite
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: parent.height * 0.4
            property color ink: button.chevronColor
            property bool pointUp: button.pointUp

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = ink
                ctx.lineWidth = Math.max(1, height / 3)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                if (pointUp) {
                    ctx.moveTo(0, height)
                    ctx.lineTo(width / 2, 0)
                    ctx.lineTo(width, height)
                } else {
                    ctx.moveTo(0, 0)
                    ctx.lineTo(width / 2, height)
                    ctx.lineTo(width, 0)
                }
                ctx.stroke()
            }

            onInkChanged: requestPaint()
            onPointUpChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: requestPaint()
        }

        Image {
            id: face
            visible: false
            source: root.themeImage("taskScrollArrowImage")
        }

        Item {
            visible: button.useSprite
            anchors.fill: parent
            clip: true

            Image {
                width: parent.width
                height: parent.height * button.frames
                y: -parent.height * button.frame
                source: face.source
                fillMode: Image.Stretch
                smooth: false
            }
        }

        Image {
            id: glyph
            visible: false
            source: root.themeImage("taskScrollArrowGlyphImage")
        }

        Item {
            visible: button.useGlyph
            anchors.centerIn: parent
            width: parent.width * 10 / 17
            height: width
            clip: true

            Image {
                width: parent.width
                height: parent.height * button.frames
                y: -parent.height * button.frame
                source: glyph.source
                fillMode: Image.Stretch
                smooth: false
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.arrowEnabled
            onClicked: button.clicked()
        }
    }

    ArrowButton {
        width: root.width
        height: root.height / 2
        pointUp: true
        arrowEnabled: root.upEnabled
        onClicked: root.upClicked()
    }

    ArrowButton {
        y: root.height / 2
        width: root.width
        height: root.height / 2
        pointUp: false
        arrowEnabled: root.downEnabled
        onClicked: root.downClicked()
    }
}
