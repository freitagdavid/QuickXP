import QtQuick
import org.kde.kwin.decoration

DecorationButton {
    id: control

    property string bgSource: ""
    property string glyphSource: ""
    property int frameCount: 1
    property int frameWidth: 28
    property int frameHeight: 20
    property int glyphCount: 1
    property int glyphFrameWidth: 0
    property int glyphFrameHeight: 0

    width: frameWidth
    height: frameHeight

    readonly property int stateIndex: {
        const last = Math.max(0, control.frameCount - 1)
        if (!control.enabled)
            return Math.min(3, last)
        if (control.pressed)
            return Math.min(2, last)
        if (control.hovered)
            return Math.min(1, last)
        return 0
    }

    FrameImage {
        anchors.fill: parent
        imageSource: control.bgSource
        frameCount: control.frameCount
        frameIndex: control.stateIndex
    }

    FrameImage {
        anchors.centerIn: parent
        width: control.glyphFrameWidth
        height: control.glyphFrameHeight
        imageSource: control.glyphSource
        frameCount: control.glyphCount
        frameIndex: Math.min(control.stateIndex, Math.max(0, control.glyphCount - 1))
        visible: control.glyphFrameWidth > 0
    }
}
