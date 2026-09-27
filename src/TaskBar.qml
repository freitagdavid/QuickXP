import Quickshell // for PanelWindow
import QtQuick // for Text

PanelWindow {
    anchors {
        bottom: true
        left: true
        right: true
    }

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    Image {
        anchors.fill: parent
        source: themeImage("taskbarImage")
        fillMode: Image.Stretch
    }

    Item {
        id: startButton

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        readonly property int frames: 3
        readonly property int frame: area.containsPress ? 2 : area.containsMouse ? 1 : 0
        width: sprite.sourceSize.height > 0
            ? height * sprite.sourceSize.width / (sprite.sourceSize.height / frames)
            : height

        Image {
            id: sprite

            width: startButton.width
            height: startButton.height * startButton.frames
            y: -startButton.height * startButton.frame
            source: themeImage("startButtonImage")
            fillMode: Image.Stretch
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    implicitHeight: Theme.sizes.taskbarHeight
    // color: Theme.colors.taskbar

    // Text {
    //     anchors.centerIn: parent

    //     text: "hello world"
    //     color: Theme.colors.taskbarText
    //     font.family: Theme.value("fonts", "ui", "Tahoma")
    //     font.pixelSize: Theme.sizes.fontSize
    // }
}
