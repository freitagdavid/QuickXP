import QtQuick

Item {
    id: frame
    property string imageSource: ""
    property int frameCount: 1
    property int frameIndex: 0
    clip: true

    Image {
        width: frame.width
        height: frame.height * Math.max(1, frame.frameCount)
        y: -frame.frameIndex * frame.height
        source: frame.imageSource
        fillMode: Image.Stretch
        visible: frame.imageSource !== ""
        smooth: true
    }
}
