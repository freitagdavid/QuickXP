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

    BorderImage {
        anchors.fill: parent
        source: themeImage("taskbarImage")
        border.top: 15
        border.bottom: 11
        horizontalTileMode: BorderImage.Repeat
        verticalTileMode: BorderImage.Stretch
    }

    Item {
        id: startButton

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        readonly property int frames: 3
        readonly property int frame: area.containsPress ? 2 : area.containsMouse ? 1 : 0
        // Luna sizing margins: left 6, right 52. Extra width stretches the middle.
        readonly property real frameScale: sprite.sourceSize.height > 0
            ? height * frames / sprite.sourceSize.height
            : 1
        readonly property int capLeft: Math.round(6 * frameScale)
        readonly property int capRight: Math.round(52 * frameScale)
        readonly property real bitmapWidth: sprite.sourceSize.width * frameScale
        width: bitmapWidth

        Image {
            id: sprite

            visible: false
            source: themeImage("startButtonImage")
        }

        Item {
            id: leftCap

            width: startButton.capLeft
            height: parent.height
            clip: true

            Image {
                width: startButton.bitmapWidth
                height: startButton.height * startButton.frames
                y: -startButton.height * startButton.frame
                source: sprite.source
                fillMode: Image.Stretch
                smooth: true
            }
        }

        Item {
            id: middle

            x: startButton.capLeft
            width: Math.max(0, parent.width - startButton.capLeft - startButton.capRight)
            height: parent.height
            clip: true

            Image {
                property real sourceMiddle: Math.max(1, sprite.sourceSize.width - 6 - 52)
                width: middle.width * sprite.sourceSize.width / sourceMiddle
                height: startButton.height * startButton.frames
                x: sprite.sourceSize.width > 0 ? -6 * width / sprite.sourceSize.width : 0
                y: -startButton.height * startButton.frame
                source: sprite.source
                fillMode: Image.Stretch
                smooth: true
            }
        }

        Item {
            anchors.right: parent.right
            width: startButton.capRight
            height: parent.height
            clip: true

            Image {
                width: startButton.bitmapWidth
                height: startButton.height * startButton.frames
                x: -(startButton.bitmapWidth - startButton.capRight)
                y: -startButton.height * startButton.frame
                source: sprite.source
                fillMode: Image.Stretch
                smooth: true
            }
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.leftMargin: Theme.value("startButton", "contentLeft", 10)
            anchors.rightMargin: Theme.value("startButton", "contentRight", 24)
            anchors.topMargin: Theme.value("startButton", "contentTop", 2) + (startButton.frame === 2 ? 1 : 0)
            anchors.bottomMargin: Math.max(0, Theme.value("startButton", "contentBottom", 4) - (startButton.frame === 2 ? 1 : 0))

            Image {
                id: flag

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 25
                height: 20
                source: themeImage("startFlagImage")
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Item {
                anchors.left: flag.right
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: label.implicitWidth + Theme.value("startButton", "shadowOffsetX", 2)
                height: label.implicitHeight + Theme.value("startButton", "shadowOffsetY", 2)

                Text {
                    x: Theme.value("startButton", "shadowOffsetX", 2)
                    y: Theme.value("startButton", "shadowOffsetY", 2)
                    text: label.text
                    color: Theme.value("startButton", "shadowColor", "#454C10")
                    font: label.font
                }

                Text {
                    id: label

                    text: Theme.value("startButton", "text", "start")
                    color: Theme.value("startButton", "textColor", "#FFFFFF")
                    font.family: Theme.value("startButton", "font", "Franklin Gothic Medium")
                    font.pointSize: Theme.value("startButton", "fontSize", 14)
                    font.italic: Theme.value("startButton", "italic", true)
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Tray {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
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
