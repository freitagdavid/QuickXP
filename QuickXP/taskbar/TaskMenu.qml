import QtQuick
import Quickshell
import qs.QuickXP

PopupWindow {
    id: menu

    property var toplevel: null

    signal chosen(string action)

    property Item anchorItem: null

    visible: false
    color: Theme.color("menu", "white")
    grabFocus: false

    property bool armed: false

    readonly property int menuWidth: 210
    readonly property int menuHeight: (appActions.length + 6) * 22 + (appActions.length > 0 ? 7 : 0) + 9

    function open() {
        if (toplevel === null || anchorItem === null)
            return
        armed = false
        // Let a tooltip popup finish closing so this one is parented to the panel.
        Qt.callLater(() => {
            if (toplevel === null)
                return
            visible = true
            armTimer.restart()
        })
    }

    function dismiss() {
        visible = false
        armed = false
        armTimer.stop()
    }

    Timer {
        id: armTimer
        interval: 250
        onTriggered: menu.armed = true
    }

    function flag(name: string, fallback: bool): bool {
        if (toplevel === null)
            return fallback
        const value = toplevel[name]
        if (value === undefined || value === null)
            return fallback
        return !!value
    }

    readonly property bool minimized: flag("minimized", false)
    readonly property bool maximized: flag("maximized", false)
    readonly property bool wayland: toplevel === null || !toplevel.kwin
    readonly property var appActions: {
        if (toplevel === null || !toplevel.appId)
            return []
        const entry = DesktopEntries.heuristicLookup(toplevel.appId)
        if (entry === null || entry.actions === undefined || entry.actions === null)
            return []
        const shown = []
        const actions = entry.actions
        for (let i = 0; i < actions.length; ++i)
            shown.push(actions[i])
        return shown
    }
    readonly property var commands: [
        { action: "restore", label: "<u>R</u>estore", enabled: minimized || maximized, shortcut: "" },
        { action: "move", label: "<u>M</u>ove", enabled: !wayland && flag("moveable", false) && !minimized && !maximized, shortcut: "" },
        { action: "resize", label: "<u>S</u>ize", enabled: !wayland && flag("resizeable", false) && !minimized && !maximized, shortcut: "" },
        { action: "minimize", label: "Mi<u>n</u>imize", enabled: flag("minimizable", true) && !minimized, shortcut: "" },
        { action: "maximize", label: "Ma<u>x</u>imize", enabled: flag("maximizable", true) && !maximized, shortcut: "" }
    ]
    readonly property var closeCommand: ({
        action: "close",
        label: "<u>C</u>lose",
        enabled: flag("closeable", true),
        shortcut: "Alt+F4"
    })

    // Corner anchors are unreliable here. Pin the popup to the panel and
    // place its top-left just above the button's top-left.
    anchor.window: anchorItem !== null ? anchorItem.QsWindow.window : null
    anchor.adjustment: PopupAdjustment.Slide
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.onAnchoring: {
        const item = menu.anchorItem
        if (item === null)
            return
        const shellWindow = item.QsWindow
        if (shellWindow === null || shellWindow.contentItem === null)
            return
        const pos = shellWindow.contentItem.mapFromItem(item, 0, -menu.menuHeight)
        menu.anchor.rect.x = pos.x
        menu.anchor.rect.y = pos.y
    }

    implicitWidth: menuWidth
    implicitHeight: menuHeight

    component MenuRow: Item {
        id: row

        property string label: ""
        property string shortcut: ""
        property bool rowEnabled: true
        signal triggered()

        readonly property bool hot: area.containsMouse && rowEnabled
        readonly property color ink: !rowEnabled
            ? "#808080"
            : hot
                ? Theme.color("highlightText", "white")
                : Theme.color("menuText", "black")

        width: body.width
        implicitWidth: line.implicitWidth + 28
        implicitHeight: 22

        Rectangle {
            anchors.fill: parent
            color: row.hot ? Theme.color("highlight", "#316AC5") : "transparent"
        }

        Row {
            id: line
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24

            Text {
                text: row.label
                textFormat: Text.RichText
                color: row.ink
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
            }

            Text {
                visible: row.shortcut !== ""
                text: row.shortcut
                color: row.ink
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: row.rowEnabled
            onClicked: row.triggered()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.color("menu", "white")
        border.width: 1
        border.color: Theme.color("border", "#003C74")

        HoverHandler {
            onHoveredChanged: {
                if (!menu.armed || hovered)
                    return
                menu.dismiss()
            }
        }

        Column {
            id: body
            x: 1
            y: 1
            width: menu.menuWidth - 2
            spacing: 0

            Repeater {
                model: menu.appActions

                delegate: MenuRow {
                    required property var modelData

                    label: modelData.name || ""
                    rowEnabled: true
                    onTriggered: {
                        modelData.execute()
                        menu.dismiss()
                    }
                }
            }

            Item {
                visible: menu.appActions.length > 0
                width: body.width
                implicitWidth: 8
                implicitHeight: visible ? 7 : 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Theme.color("border", "#003C74")
                }
            }

            Repeater {
                model: menu.commands

                delegate: MenuRow {
                    required property var modelData

                    label: modelData.label
                    shortcut: modelData.shortcut
                    rowEnabled: modelData.enabled
                    onTriggered: {
                        menu.chosen(modelData.action)
                        menu.dismiss()
                    }
                }
            }

            Item {
                width: body.width
                implicitWidth: 8
                implicitHeight: 7

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Theme.color("border", "#003C74")
                }
            }

            MenuRow {
                label: menu.closeCommand.label
                shortcut: menu.closeCommand.shortcut
                rowEnabled: menu.closeCommand.enabled
                onTriggered: {
                    menu.chosen(menu.closeCommand.action)
                    menu.dismiss()
                }
            }
        }
    }
}
