import QtQuick

// Sits behind the decorated preview so glass blur has a scene to sample.
Window {
    id: backdrop
    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint
    title: "QuickXP decoration backdrop"
    color: "#1b2838"

    readonly property var swatches: [
        "#e85d4c", "#f0c14a", "#3d9b6e", "#3a7bd5",
        "#7b4b94", "#e07a3d", "#2a9d8f", "#f4a261",
        "#264653", "#e9c46a", "#d64d6b", "#4cc9f0"
    ]

    Repeater {
        model: 24
        Rectangle {
            required property int index
            readonly property int columns: 6
            readonly property real cellW: backdrop.width / columns
            readonly property real cellH: backdrop.height / 4
            x: (index % columns) * cellW
            y: Math.floor(index / columns) * cellH
            width: cellW
            height: cellH
            color: backdrop.swatches[index % backdrop.swatches.length]
        }
    }
}
