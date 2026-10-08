import Quickshell // for PanelWindow
import Quickshell.Wayland
import QtQuick // for Text
import QtQuick.Dialogs
import qs.QuickXP
import qs.QuickXP.tray
import qs.QuickXP.settings
import qs.QuickXP.start
import "../ToolbarModel.js" as ToolbarModel

PanelWindow {
    id: taskbarWindow

    // Injected by Variants over Quickshell.screens
    required property var modelData
    screen: modelData
    reloadableId: "quickxp-taskbar-" + String(modelData && modelData.name ? modelData.name : "default")

    anchors {
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // Vista's orb sits on the bar and clears the top edge by only a few pixels.
    readonly property int barHeight: Config.options.taskbarHeight > 0
        ? Config.options.taskbarHeight
        : Theme.sizes.taskbarHeight
    readonly property int startOverhang: startButton.nativeFrame ? 6 : 0
    implicitHeight: barHeight + startOverhang
    exclusiveZone: barHeight

    readonly property bool glass: GenerationPolicy.glass

    mask: Region {
        item: taskbarBand
        Region { item: startButton }
    }

    BackgroundEffect.blurRegion: glass ? taskbarGlass : null

    Region {
        id: taskbarGlass
        item: taskbarBand
    }

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    function clampBorder(value, sourceSize, fallback): int {
        const raw = Number(value)
        const chosen = (raw === undefined || raw === null || isNaN(raw)) ? fallback : raw
        const maxEdge = Math.max(0, Math.floor((Math.max(1, sourceSize) - 1) / 2))
        return Math.max(0, Math.min(Math.round(chosen), maxEdge))
    }

    Image {
        id: taskbarSprite
        visible: false
        source: themeImage("taskbarImage")
    }

    Item {
        id: taskbarBand
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: taskbarWindow.barHeight
    }

    Rectangle {
        anchors.left: taskbarBand.left
        anchors.right: taskbarBand.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        color: Theme.color("taskbar", "#245EDC")
        visible: taskbarSprite.sourceSize.width <= 0
    }

    BorderImage {
        anchors.left: taskbarBand.left
        anchors.right: taskbarBand.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        source: taskbarSprite.source
        border.left: taskbarWindow.clampBorder(Theme.value("taskbar", "borderLeft", 0), taskbarSprite.sourceSize.width, 0)
        border.right: taskbarWindow.clampBorder(Theme.value("taskbar", "borderRight", 0), taskbarSprite.sourceSize.width, 0)
        border.top: taskbarWindow.clampBorder(Theme.value("taskbar", "borderTop", 15), taskbarSprite.sourceSize.height, 15)
        border.bottom: taskbarWindow.clampBorder(Theme.value("taskbar", "borderBottom", 11), taskbarSprite.sourceSize.height, 11)
        horizontalTileMode: BorderImage.Repeat
        verticalTileMode: BorderImage.Stretch
        visible: taskbarSprite.sourceSize.width > 0
    }

    Item {
        id: startButton

        // Stretch (XP) sits on the bottom edge with a small top grip inset.
        // TrueSize (Vista orb) is bottom-flush and a few pixels taller than the
        // bar, so only the top of the pearl hangs over.
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        readonly property int topInset: Math.max(0, Number(Theme.value("startButton", "contentTop", 2)))
        readonly property bool nativeFrame: trueSize && sprite.sourceSize.height > 0
        anchors.bottomMargin: 0
        height: nativeFrame
            ? taskbarWindow.barHeight + taskbarWindow.startOverhang
            : Math.max(1, taskbarWindow.barHeight - topInset)
        z: 1

        readonly property int frames: Math.max(1, Number(Theme.value("startButton", "frames", 3)))
        readonly property int frame: area.containsPress ? 2 : area.containsMouse ? 1 : 0
        // SizingMargins from [Start::Button] (Luna/Zune default 6, 52, …).
        readonly property int marginLeft: Number(Theme.value("startButton", "borderLeft", 6))
        readonly property int marginRight: Number(Theme.value("startButton", "borderRight", 52))

        // Luna is vertical; Candy/TrueSize packs often use a horizontal strip.
        readonly property bool horizontalFrames: {
            const layout = String(Theme.value("startButton", "imageLayout", "")).toLowerCase()
            if (layout === "horizontal")
                return true
            if (layout === "vertical")
                return false
            const w = sprite.sourceSize.width
            const h = sprite.sourceSize.height
            const f = startButton.frames
            if (f > 1 && w > 0 && h > 0 && (w % f) === 0 && (h % f) !== 0)
                return true
            if (f > 1 && w > 0 && h > 0 && (w % f) === 0 && (h % f) === 0) {
                const fw = w / f
                return fw >= h
            }
            return false
        }

        readonly property bool trueSize: {
            const sizing = String(Theme.value("startButton", "sizingType", "stretch")).toLowerCase()
            return sizing === "truesize" || sizing === "true size"
        }

        readonly property int frameSrcW: {
            const w = sprite.sourceSize.width
            if (w <= 0)
                return 1
            return startButton.horizontalFrames
                ? Math.max(1, Math.floor(w / startButton.frames))
                : w
        }
        readonly property int frameSrcH: {
            const h = sprite.sourceSize.height
            if (h <= 0)
                return 1
            return startButton.horizontalFrames
                ? h
                : Math.max(1, Math.floor(h / startButton.frames))
        }

        readonly property real frameScale: frameSrcH > 0 ? height / frameSrcH : 1
        readonly property int capLeft: Math.round(marginLeft * frameScale)
        readonly property int capRight: Math.round(marginRight * frameScale)
        readonly property real frameWidth: frameSrcW * frameScale
        // TrueSize / horizontal: one frame wide. Luna vertical: full strip scaled (3-cap).
        readonly property real bitmapWidth: startButton.horizontalFrames || startButton.trueSize
            ? frameWidth
            : sprite.sourceSize.width * frameScale
        width: bitmapWidth + Theme.value("startButton", "extraWidth", 0)

        readonly property int contentLeft: {
            const v = Number(Theme.value("startButton", "contentLeft", 10))
            if (isNaN(v) || v < 0 || v > width * 0.6)
                return 8
            return Math.round(v)
        }
        readonly property int contentRight: {
            const v = Number(Theme.value("startButton", "contentRight", 24))
            if (isNaN(v) || v < 0 || startButton.contentLeft + v >= width)
                return 8
            return Math.round(v)
        }

        Image {
            id: sprite

            visible: false
            source: themeImage("startButtonImage")
        }

        // Simple strip (Candy TrueSize / horizontal frames).
        Item {
            anchors.fill: parent
            clip: true
            visible: startButton.horizontalFrames || startButton.trueSize

            Image {
                width: startButton.horizontalFrames
                    ? startButton.frameWidth * startButton.frames
                    : startButton.frameWidth
                height: startButton.horizontalFrames
                    ? startButton.height
                    : startButton.height * startButton.frames
                x: startButton.horizontalFrames
                    ? -startButton.frameWidth * startButton.frame
                    : 0
                y: startButton.horizontalFrames
                    ? 0
                    : -startButton.height * startButton.frame
                source: sprite.source
                fillMode: Image.Stretch
                smooth: true
            }
        }

        // Luna-style vertical strip with left/middle/right caps.
        Item {
            anchors.fill: parent
            visible: !startButton.horizontalFrames && !startButton.trueSize

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
                    property real sourceMiddle: Math.max(
                        1,
                        sprite.sourceSize.width - startButton.marginLeft - startButton.marginRight
                    )
                    width: middle.width * sprite.sourceSize.width / sourceMiddle
                    height: startButton.height * startButton.frames
                    x: sprite.sourceSize.width > 0
                        ? -startButton.marginLeft * width / sprite.sourceSize.width
                        : 0
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
        }

        Item {
            id: content

            anchors.fill: parent
            anchors.leftMargin: startButton.contentLeft
            anchors.rightMargin: startButton.contentRight
            anchors.topMargin: Math.max(0, Number(Theme.value("startButton", "contentTop", 2))) + (startButton.frame === 2 ? 1 : 0)
            anchors.bottomMargin: Math.max(0, Number(Theme.value("startButton", "contentBottom", 4)) - (startButton.frame === 2 ? 1 : 0))

            Image {
                id: flag

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? 25 : 0
                height: visible ? 20 : 0
                visible: Theme.composeStartFlag && source.toString() !== ""
                source: Theme.composeStartFlag ? themeImage("startFlagImage") : ""
                fillMode: Image.PreserveAspectFit
                smooth: false
            }

            Item {
                anchors.left: flag.right
                anchors.leftMargin: flag.visible ? 0 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: label.implicitWidth + Theme.value("startButton", "shadowOffsetX", 2)
                height: label.implicitHeight + Theme.value("startButton", "shadowOffsetY", 2)

                Text {
                    x: Theme.value("startButton", "shadowOffsetX", 2)
                    y: Theme.value("startButton", "shadowOffsetY", 2)
                    text: label.text
                    color: Theme.value("startButton", "shadowColor", "#454C10")
                    font: label.font
                    visible: {
                        const section = Theme.data.startButton
                        return !!(section && section.shadowColor)
                    }
                }

                Text {
                    id: label

                    text: Theme.value("startButton", "text", "start")
                    color: Theme.value("startButton", "textColor", "#FFFFFF")
                    font.family: Theme.value("startButton", "font", "Franklin Gothic Medium")
                    font.pointSize: Math.max(8, Number(Theme.value("startButton", "fontSize", 14)))
                    font.italic: Theme.value("startButton", "italic", true)
                    font.bold: Theme.value("startButton", "bold", false)
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    startChromeMenu.open()
                else if (mouse.button === Qt.LeftButton)
                    startPopup.toggle()
            }
        }

        StartChromeMenu {
            id: startChromeMenu
            anchorItem: startButton
        }

        StartPopupHost {
            id: startPopup
            anchorItem: startButton
            screen: taskbarWindow.screen
            persistKey: String(taskbarWindow.modelData && taskbarWindow.modelData.name
                               ? taskbarWindow.modelData.name
                               : "default")

            Component.onCompleted: StartService.register(startPopup)
            Component.onDestruction: StartService.unregister(startPopup)
        }
    }

    QuickLaunch {
        id: quickLaunch
        anchors.left: startButton.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        anchors.leftMargin: visible ? 2 : 0
        width: visible ? implicitWidth : 0
    }

    TaskbarToolbars {
        id: extraToolbars
        anchors.left: quickLaunch.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        anchors.leftMargin: visible && width > 0 ? 2 : 0
    }

    TaskList {
        anchors.left: extraToolbars.right
        anchors.right: tray.left
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.topMargin: 3
        anchors.bottomMargin: 2
    }

    Tray {
        id: tray
        anchors.right: showDesktopEdge.visible ? showDesktopEdge.left : parent.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        anchors.rightMargin: showDesktopEdge.visible ? 0 : 0
    }

    // Win7 far-right Show Desktop (GenerationPolicy showDesktop === win7).
    Rectangle {
        id: showDesktopEdge
        readonly property bool active: String(GenerationPolicy.forItem("showDesktop") || "") === "win7"
        visible: active
        anchors.right: parent.right
        anchors.top: taskbarBand.top
        anchors.bottom: taskbarBand.bottom
        width: visible ? 6 : 0
        color: Qt.rgba(1, 1, 1, showDesktopEdgeArea.containsMouse ? 0.35 : 0.15)

        MouseArea {
            id: showDesktopEdgeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: TasksService.toggleShowDesktop()
        }
    }

    // Empty-band Toolbars context menu (Epic 4 / BAR-20 stub).
    MouseArea {
        anchors.fill: taskbarBand
        z: -1
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                toolbarsMenu.open()
        }
    }

    function homePath(leaf: string): string {
        const home = String(Quickshell.env("HOME") || "")
        if (!home)
            return leaf
        return home + "/" + leaf
    }

    function toolbarChecked(id: string): bool {
        return ToolbarModel.isVisible(Config.options.taskbarToolbars, id)
    }

    function toggleFolderToolbar(id: string, path: string) {
        Config.options.taskbarToolbars = ToolbarModel.toggleFolder(
            Config.options.taskbarToolbars, id, path, 120)
    }

    FolderDialog {
        id: newToolbarDialog
        title: "New Toolbar — Choose Folder"
        onAccepted: {
            const url = String(selectedFolder || "")
            let path = url
            if (path.startsWith("file://"))
                path = decodeURIComponent(path.slice(7))
            if (!path)
                return
            const parts = path.split("/")
            const name = parts[parts.length - 1] || "Toolbar"
            Config.options.taskbarToolbars = ToolbarModel.upsertFolder(
                Config.options.taskbarToolbars, name, path, 140)
        }
    }

    PopupWindow {
        id: toolbarsMenu
        visible: false
        color: Theme.color("menu", "#FFFFFF")
        grabFocus: true
        implicitWidth: 200
        implicitHeight: 148

        function open() {
            toolbarsMenu.anchor.item = startButton
            visible = true
        }

        anchor.item: startButton
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 4
            Text {
                text: "Toolbars"
                font.bold: true
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
            }
            Text {
                text: (Config.options.showQuickLaunch ? "✓ " : "  ") + "Quick Launch"
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Config.options.showQuickLaunch = !Config.options.showQuickLaunch
                        toolbarsMenu.visible = false
                    }
                }
            }
            Text {
                text: (taskbarWindow.toolbarChecked("Desktop") ? "✓ " : "  ") + "Desktop"
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        taskbarWindow.toggleFolderToolbar("Desktop", taskbarWindow.homePath("Desktop"))
                        toolbarsMenu.visible = false
                    }
                }
            }
            Text {
                text: (taskbarWindow.toolbarChecked("Links") ? "✓ " : "  ") + "Links"
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        taskbarWindow.toggleFolderToolbar("Links", taskbarWindow.homePath("Links"))
                        toolbarsMenu.visible = false
                    }
                }
            }
            Text {
                text: "  New Toolbar..."
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        toolbarsMenu.visible = false
                        newToolbarDialog.open()
                    }
                }
            }
            Text {
                text: "  Language Bar"
                color: "#808080"
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
            }
        }
    }

}
