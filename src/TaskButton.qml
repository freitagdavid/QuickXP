import QtQuick
import Quickshell

Item {
    id: root

    clip: true

    property var toplevel: null
    property Item taskList: null

    readonly property bool focused: toplevel !== null && toplevel.activated && !toplevel.minimized
    readonly property int frames: 6
    // 0 normal, 1 hot, 2 pressed, 4 checked (focused), 5 hot-checked.
    readonly property int frame: {
        if (area.containsPress)
            return 2
        if (focused && area.containsMouse)
            return 5
        if (focused)
            return 4
        if (area.containsMouse)
            return 1
        return 0
    }
    // Luna sizing margins: left 17, right 5. Extra width stretches the middle.
    readonly property real frameScale: sprite.sourceSize.height > 0
        ? height * frames / sprite.sourceSize.height
        : 1
    readonly property int capLeft: Math.round(17 * frameScale)
    readonly property int capRight: Math.round(5 * frameScale)
    readonly property real bitmapWidth: sprite.sourceSize.width * frameScale
    readonly property bool useSprite: sprite.status === Image.Ready

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    function fileUrl(path: string): string {
        if (path === "" || path.startsWith("file:") || path.startsWith("image:") || path.startsWith("qrc:"))
            return path
        if (path.startsWith("/"))
            return "file://" + path
        return path
    }

    readonly property string iconSource: {
        let name = ""
        if (toplevel !== null && toplevel.appId !== "") {
            const entry = DesktopEntries.heuristicLookup(toplevel.appId)
            if (entry !== null && entry.icon)
                name = entry.icon
        }
        const path = name !== ""
            ? Quickshell.iconPath(name, "application-x-executable")
            : Quickshell.iconPath("application-x-executable")
        return fileUrl(path)
    }

    readonly property string title: toplevel !== null ? toplevel.title : ""

    function updateRect() {
        const target = toplevel
        if (target === null || typeof target.setRectangle !== "function")
            return
        const window = QsWindow.window
        if (window === null)
            return
        const rect = QsWindow.itemRect(root)
        target.setRectangle(window, Qt.rect(rect.x, rect.y, rect.width, rect.height))
    }

    function clearRect() {
        if (toplevel !== null && typeof toplevel.unsetRectangle === "function")
            toplevel.unsetRectangle()
    }

    function showTip() {
        tooltip.visible = false
        tooltipTimer.restart()
    }

    function hideTip() {
        tooltipTimer.stop()
        tooltip.visible = false
    }

    onXChanged: updateRect()
    onYChanged: updateRect()
    onWidthChanged: updateRect()
    onHeightChanged: updateRect()
    Component.onCompleted: updateRect()
    Component.onDestruction: clearRect()

    Timer {
        id: tooltipTimer
        interval: 400
        onTriggered: {
            const elided = label.truncated || !label.visible
            if (root.title !== "" && elided) {
                tooltip.title = root.title
                tooltip.visible = true
            }
        }
    }

    PopupWindow {
        id: tooltip

        property string title: ""

        visible: false
        color: "#FFFFE1"
        grabFocus: false
        implicitWidth: tip.implicitWidth + 8
        implicitHeight: tip.implicitHeight + 6

        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 2

        Rectangle {
            anchors.fill: parent
            color: "#FFFFE1"
            border.color: "black"
            border.width: 1

            Text {
                id: tip
                x: 4
                y: 2
                text: tooltip.title
                color: "black"
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
            }
        }
    }

    Rectangle {
        visible: !root.useSprite
        anchors.fill: parent
        color: root.focused ? "#9DC7FF" : Theme.color("taskbar", "#245EDC")
        border.width: 1
        border.color: root.focused ? "#E7F1FF" : "#0C3E9E"
    }

    Image {
        id: sprite
        visible: false
        source: root.themeImage("taskButtonImage")
    }

    Item {
        id: leftCap
        visible: root.useSprite
        width: root.capLeft
        height: parent.height
        clip: true

        Image {
            width: root.bitmapWidth
            height: root.height * root.frames
            y: -root.height * root.frame
            source: sprite.source
            fillMode: Image.Stretch
            smooth: true
        }
    }

    Item {
        id: middle
        visible: root.useSprite
        x: root.capLeft
        width: Math.max(0, parent.width - root.capLeft - root.capRight)
        height: parent.height
        clip: true

        Image {
            property real sourceMiddle: Math.max(1, sprite.sourceSize.width - 17 - 5)
            width: middle.width * sprite.sourceSize.width / sourceMiddle
            height: root.height * root.frames
            x: sprite.sourceSize.width > 0 ? -17 * width / sprite.sourceSize.width : 0
            y: -root.height * root.frame
            source: sprite.source
            fillMode: Image.Stretch
            smooth: true
        }
    }

    Item {
        visible: root.useSprite
        anchors.right: parent.right
        width: root.capRight
        height: parent.height
        clip: true

        Image {
            width: root.bitmapWidth
            height: root.height * root.frames
            x: -(root.bitmapWidth - root.capRight)
            y: -root.height * root.frame
            source: sprite.source
            fillMode: Image.Stretch
            smooth: true
        }
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: root.frame === 2 ? 3 : 2
        anchors.bottomMargin: root.frame === 2 ? 1 : 2

        Image {
            id: icon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: status === Image.Ready ? 16 : 0
            height: 16
            source: root.iconSource
            sourceSize.width: 16
            sourceSize.height: 16
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: false
        }

        Text {
            id: label
            anchors.left: icon.right
            anchors.leftMargin: icon.width > 0 ? 4 : 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 8
            text: root.title
            elide: Text.ElideRight
            color: Theme.color("taskbarText", "white")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        onContainsMouseChanged: {
            if (containsMouse && (taskList === null || !taskList.taskMenuOpen))
                root.showTip()
            else
                root.hideTip()
        }

        // clicked() is the release. A right-click release often never
        // arrives, so the menu opens on the press.
        onPressed: (mouse) => {
            if (mouse.button !== Qt.RightButton || taskList === null)
                return
            const target = root.toplevel
            if (target === null)
                return
            root.hideTip()
            taskList.openTaskMenu(root, target)
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                return
            const target = root.toplevel
            if (target === null)
                return
            root.hideTip()
            if (target.kwin) {
                const action = target.activated && !target.minimized ? "minimize" : "activate"
                root.sendCommand(target.windowId, action)
                return
            }
            if (target.activated && !target.minimized)
                target.minimized = true
            else {
                target.minimized = false
                target.activate()
            }
        }
    }

    function sendCommand(windowId: string, action: string) {
        Quickshell.execDetached([
            "qdbus6", "org.quickxp.Tasks", "/org/quickxp/Tasks",
            "org.quickxp.Tasks.Command", windowId, action
        ])
    }
}
