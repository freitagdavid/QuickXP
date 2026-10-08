import QtQuick
import org.kde.kwin.decoration
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import "ThemeMetrics.js" as Theme

Decoration {
    id: root
    alpha: true
    property bool supportsMask: true
    property alias decorationMask: maskItem.mask

    readonly property bool active: decoration.client.active
    readonly property var metrics: Theme.metrics
    readonly property int captionH: metrics.borderTop
    readonly property color plate: metrics.plateColor || "#409EFE"
    // The theme byte is only ~9% active. Item opacity on these rects was too
    // faint to read, so the alpha is painted into the color at about half.
    readonly property real plateAlpha: Math.min(1, ((root.active ? metrics.activePlateAlpha : metrics.inactivePlateAlpha) || 0) * 6)
    readonly property color plateFill: Qt.rgba(plate.r, plate.g, plate.b, plateAlpha)
    // Keep the curve inside the frame. A larger radius than the border leaves
    // a gap where the side strip and the bottom cap do not meet.
    readonly property int cornerRadius: Math.max(1, Math.min(
        metrics.borderLeft || 1,
        metrics.borderRight || 1,
        metrics.borderBottom || 1
    ))

    Component.onCompleted: {
        borders.left = Qt.binding(function() { return Theme.metrics.borderLeft })
        borders.right = Qt.binding(function() { return Theme.metrics.borderRight })
        borders.top = Qt.binding(function() { return Theme.metrics.borderTop })
        borders.bottom = Qt.binding(function() { return Theme.metrics.borderBottom })
        maximizedBorders.left = 0
        maximizedBorders.right = 0
        maximizedBorders.bottom = 0
        maximizedBorders.top = Qt.binding(function() { return Theme.metrics.borderTop })
    }

    function partUrl(id) {
        const entry = Theme.part(id)
        if (!entry || !entry.image)
            return ""
        return entry.image
    }

    function frameOf(id) {
        return Theme.part(id)
    }

    Item {
        id: shaped
        anchors.fill: parent

        Item {
            id: topCap
            width: parent.width
            height: Math.min(root.cornerRadius, root.captionH)
            clip: true
            Rectangle {
                width: parent.width
                height: root.cornerRadius * 2
                radius: root.cornerRadius
                color: root.plateFill
            }
        }
        Rectangle {
            y: topCap.height
            width: parent.width
            height: Math.max(0, root.captionH - topCap.height)
            color: root.plateFill
        }
        Rectangle {
            x: 0
            y: root.captionH
            width: borders.left
            height: Math.max(0, parent.height - root.captionH - root.cornerRadius)
            color: root.plateFill
        }
        Rectangle {
            x: parent.width - borders.right
            y: root.captionH
            width: borders.right
            height: Math.max(0, parent.height - root.captionH - root.cornerRadius)
            color: root.plateFill
        }
        Item {
            y: parent.height - root.cornerRadius
            width: parent.width
            height: root.cornerRadius
            clip: true
            Rectangle {
                y: -root.cornerRadius
                width: parent.width
                height: root.cornerRadius * 2
                radius: root.cornerRadius
                color: root.plateFill
            }
        }

        Item {
        id: reflectionClip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.captionH
        clip: true
        visible: Theme.roleId("reflection") !== 0
        readonly property var entry: root.frameOf(Theme.roleId("reflection"))
        opacity: entry && entry.partOpacity !== undefined ? entry.partOpacity : 1
        Image {
            source: root.partUrl(Theme.roleId("reflection"))
            smooth: true
        }
    }

    FrameImage {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.captionH
        visible: highlightId !== 0
        readonly property int highlightId: root.active
            ? Theme.roleId("captionHighlightActive")
            : Theme.roleId("captionHighlightInactive")
        readonly property var entry: root.frameOf(highlightId)
        imageSource: root.partUrl(highlightId)
        frameCount: entry ? entry.imageCount : 1
        frameIndex: 0
        opacity: (entry && entry.partOpacity !== undefined ? entry.partOpacity : 1) * 0.35
    }

        Item {
        id: titleRow
        x: root.borders.left
        y: 0
        width: Math.max(0, parent.width - root.borders.left - root.borders.right)
        height: root.captionH

        DecorationButton {
            id: menuButton
            buttonType: DecorationOptions.DecorationButtonMenu
            width: metrics.iconSize
            height: metrics.iconSize
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 2
            Kirigami.Icon {
                anchors.fill: parent
                source: decoration.client.icon
                smooth: true
            }
        }

        Row {
            id: buttons
            anchors.right: parent.right
            // anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            // anchors.bottomMargin: 10

            CaptionButton {
                buttonType: DecorationOptions.DecorationButtonMinimize
                visible: decoration.client.minimizeable
                bgSource: root.partUrl(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))
                glyphSource: root.partUrl(Theme.pickGlyph("minGlyphs", root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")))
                frameCount: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).imageCount || 1
                frameWidth: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).frameWidth || 0
                frameHeight: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).frameHeight || 0
                glyphCount: (root.frameOf(Theme.pickGlyph("minGlyphs", root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).imageCount || 1
                glyphFrameWidth: (root.frameOf(Theme.pickGlyph("minGlyphs", root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).frameWidth || 0
                glyphFrameHeight: (root.frameOf(Theme.pickGlyph("minGlyphs", root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).frameHeight || 0
            }
            CaptionButton {
                buttonType: decoration.client.maximized
                    ? DecorationOptions.DecorationButtonMaximizeRestore
                    : DecorationOptions.DecorationButtonMaximizeRestore
                visible: decoration.client.maximizeable
                readonly property string glyphRole: decoration.client.maximized ? "restoreGlyphs" : "maxGlyphs"
                bgSource: root.partUrl(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))
                glyphSource: root.partUrl(Theme.pickGlyph(glyphRole, root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")))
                frameCount: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).imageCount || 1
                frameWidth: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).frameWidth || 0
                frameHeight: (root.frameOf(root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive")) || {}).frameHeight || 0
                glyphCount: (root.frameOf(Theme.pickGlyph(glyphRole, root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).imageCount || 1
                glyphFrameWidth: (root.frameOf(Theme.pickGlyph(glyphRole, root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).frameWidth || 0
                glyphFrameHeight: (root.frameOf(Theme.pickGlyph(glyphRole, root.active ? Theme.roleId("buttonBgActive") : Theme.roleId("buttonBgInactive"))) || {}).frameHeight || 0
            }
            CaptionButton {
                buttonType: DecorationOptions.DecorationButtonClose
                visible: decoration.client.closeable
                bgSource: root.partUrl(root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive"))
                glyphSource: root.partUrl(Theme.pickGlyph("closeGlyphs", root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive")))
                frameCount: (root.frameOf(root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive")) || {}).imageCount || 1
                frameWidth: (root.frameOf(root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive")) || {}).frameWidth || 0
                frameHeight: (root.frameOf(root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive")) || {}).frameHeight || 0
                glyphCount: (root.frameOf(Theme.pickGlyph("closeGlyphs", root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive"))) || {}).imageCount || 1
                glyphFrameWidth: (root.frameOf(Theme.pickGlyph("closeGlyphs", root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive"))) || {}).frameWidth || 0
                glyphFrameHeight: (root.frameOf(Theme.pickGlyph("closeGlyphs", root.active ? Theme.roleId("closeBgActive") : Theme.roleId("closeBgInactive"))) || {}).frameHeight || 0
            }
        }

        Text {
            id: titleText
            text: decoration.client.caption
            color: root.active ? (metrics.titleActiveText || "#000000") : (metrics.titleInactiveText || "#000000")
            font.pixelSize: metrics.fontSize || 12
            font.family: metrics.fontFamily || "Segoe UI"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: menuButton.right
            anchors.leftMargin: 4
            anchors.right: buttons.left
            anchors.rightMargin: 6
            elide: Text.ElideRight
            style: Text.Outline
            styleColor: metrics.glowColor || "#FFFFFF"
            z: 1
        }
        Image {
            readonly property int glowId: Theme.roleId("titleGlow")
            readonly property var entry: root.frameOf(glowId)
            visible: glowId !== 0
            source: root.partUrl(glowId)
            x: titleText.x - ((entry && entry.contentMargins) ? entry.contentMargins[0] : 0)
            y: titleText.y - ((entry && entry.contentMargins) ? entry.contentMargins[2] : 0)
            width: titleText.contentWidth + ((entry && entry.contentMargins) ? entry.contentMargins[0] + entry.contentMargins[1] : 0)
            height: titleText.contentHeight + ((entry && entry.contentMargins) ? entry.contentMargins[2] + entry.contentMargins[3] : 0)
            fillMode: Image.Stretch
            smooth: true
            z: 0
        }
    }
    }

    KSvg.FrameSvgItem {
        id: maskItem
        anchors.fill: parent
        imagePath: Qt.resolvedUrl("mask.svg")
        opacity: 0
    }
}
