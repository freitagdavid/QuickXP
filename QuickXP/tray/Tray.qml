import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.SystemTray
import qs.QuickXP

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.size("taskbarHeight", 30)

    readonly property int iconSize: 16
    property bool expanded: false

    function themeImage(key: string): string {
        const path = Theme.image(key)
        if (path === "" || path.startsWith("file:"))
            return path
        return "file://" + path
    }

    // SNI "Active" still means the icon can sit in the overflow. Only
    // NeedsAttention stays out while the tray is contracted.
    function collapsed(item): bool {
        return item.status !== Status.NeedsAttention
    }

    readonly property bool hasHidden: {
        const items = SystemTray.items.values
        for (let i = 0; i < items.length; ++i) {
            if (collapsed(items[i]))
                return true
        }
        return false
    }

    onHasHiddenChanged: {
        if (!hasHidden)
            expanded = false
    }

    function showTip(item, title, body) {
        const nextTitle = (title || "").trim()
        const nextBody = (body || "").trim()
        const detail = nextBody !== "" && nextBody !== nextTitle ? nextBody : ""
        if (nextTitle === "" && detail === "") {
            hideTip(item)
            return
        }

        tooltip.hoverItem = item
        tooltip.anchor.item = item
        tooltip.title = nextTitle
        tooltip.body = detail
        tooltip.visible = false
        tooltipTimer.restart()
    }

    function hideTip(item) {
        if (item !== undefined && item !== null && tooltip.hoverItem !== item)
            return
        tooltip.hoverItem = null
        tooltipTimer.stop()
        tooltip.visible = false
    }

    // Close tray tips + sibling control popups before opening another (Wayland
    // dislikes a new grabbing popup under a different ProxiedWindow parent).
    function dismissControlPopups() {
        hideTip(null)
    }

    function closeTrayPopups(except) {
        hideTip(null)
        if (systemControls && typeof systemControls.closeAllPopups === "function")
            systemControls.closeAllPopups(except)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Timer {
        id: tooltipTimer
        interval: 400
        onTriggered: {
            if (tooltip.hoverItem !== null)
                tooltip.visible = true
        }
    }

    PopupWindow {
        id: tooltip

        property string title: ""
        property string body: ""
        property Item hoverItem: null

        visible: false
        color: "#FFFFE1"
        grabFocus: false
        implicitWidth: tip.implicitWidth + 8
        implicitHeight: tip.implicitHeight + 6

        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: 2

        Rectangle {
            anchors.fill: parent
            color: "#FFFFE1"
            border.color: "black"
            border.width: 1

            Column {
                id: tip
                x: 4
                y: 2
                spacing: 0

                Text {
                    visible: text !== ""
                    text: tooltip.title
                    color: "black"
                    font.family: Theme.value("fonts", "ui", "Tahoma")
                    font.pixelSize: Theme.size("fontSize", 11)
                }

                Text {
                    visible: text !== ""
                    text: tooltip.body
                    color: "black"
                    font.family: Theme.value("fonts", "ui", "Tahoma")
                    font.pixelSize: Theme.size("fontSize", 11)
                }
            }
        }
    }

    Item {
        id: plate

        anchors.fill: parent

        BorderImage {
            anchors.fill: parent
            source: root.themeImage("trayImage")
            border.left: 34
            border.right: 10
            border.top: 12
            border.bottom: 12
            horizontalTileMode: BorderImage.Stretch
            verticalTileMode: BorderImage.Stretch
        }
    }

    Row {
        id: row

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 2

        Item {
            id: chevron

            visible: root.hasHidden
            readonly property int spriteWidth: 19
            readonly property int spriteHeight: 20
            width: visible ? spriteWidth : 0
            height: row.height

            Item {
                id: chevronSprite

                anchors.centerIn: parent
                width: chevron.spriteWidth
                height: chevron.spriteHeight
                clip: true

                readonly property int frame: chevronArea.containsPress ? 2 : chevronArea.containsMouse ? 1 : 0

                Image {
                    width: chevronSprite.width
                    height: chevronSprite.height * 3
                    y: -chevronSprite.height * chevronSprite.frame
                    source: root.themeImage(root.expanded ? "trayChevronOpenImage" : "trayChevronImage")
                    fillMode: Image.Stretch
                    smooth: false
                }
            }

            MouseArea {
                id: chevronArea

                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.expanded = !root.expanded
            }
        }

        TraySystemControls {
            id: systemControls
            trayRoot: root
            height: row.height
        }

        Repeater {
            // Delegates are parented to the row. Keep the repeater itself out of the layout.
            visible: false
            model: SystemTray.items

            delegate: Item {
                id: iconItem

                required property var modelData

                readonly property bool shown: root.expanded || !root.collapsed(modelData)

                visible: shown || width > 0
                width: shown ? root.iconSize : 0
                height: row.height

                Behavior on width {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }

                Item {
                    anchors.centerIn: parent
                    width: root.iconSize + 1
                    height: root.iconSize + 1

                    // 1px black silhouette offset — reads as a crisp drop shadow / outline.
                    // Keep Image sync: ColorOverlay + async pixmap load trips cross-thread QObject warnings.
                    ColorOverlay {
                        x: 1
                        y: 1
                        width: root.iconSize
                        height: root.iconSize
                        source: trayIcon
                        color: "black"
                        visible: trayIcon.status === Image.Ready
                    }

                    Image {
                        id: trayIcon
                        width: root.iconSize
                        height: root.iconSize
                        source: iconItem.modelData.icon
                        sourceSize.width: root.iconSize
                        sourceSize.height: root.iconSize
                        fillMode: Image.PreserveAspectFit
                        asynchronous: false
                        smooth: false
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onContainsMouseChanged: {
                        if (containsMouse) {
                            root.showTip(
                                iconItem,
                                iconItem.modelData.tooltipTitle,
                                iconItem.modelData.tooltipDescription)
                        } else {
                            root.hideTip(iconItem)
                        }
                    }

                    onClicked: (mouse) => {
                        const item = iconItem.modelData
                        root.hideTip(iconItem)
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu)
                                trayMenu.open()
                            return
                        }
                        item.activate()
                    }

                    onWheel: (wheel) => {
                        const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                        iconItem.modelData.scroll(
                            horizontal ? wheel.angleDelta.x : wheel.angleDelta.y,
                            horizontal)
                    }
                }

                QsMenuAnchor {
                    id: trayMenu

                    menu: iconItem.modelData.menu
                    anchor.item: iconItem
                    anchor.edges: Edges.Top
                    anchor.gravity: Edges.Top

                    onOpened: root.hideTip(iconItem)
                }
            }
        }

        Item {
            id: clockCell
            visible: Config.options.trayShowClock
            width: visible ? clockCol.implicitWidth + 10 : 0
            height: row.height

            readonly property bool tall: {
                const h = Config.options.taskbarHeight > 0
                    ? Config.options.taskbarHeight
                    : Theme.size("taskbarHeight", 30)
                return h >= 40
            }

            Column {
                id: clockCol
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                spacing: 0

                Text {
                    id: clockLabel
                    text: Qt.formatTime(clock.date, "h:mm AP")
                    color: Theme.color("taskbarText", "white")
                    font.family: Theme.value("fonts", "ui", "Tahoma")
                    font.pixelSize: Theme.size("fontSize", 11)
                }

                Text {
                    visible: clockCell.tall
                    text: Qt.formatDate(clock.date, "ddd M/d")
                    color: Theme.color("taskbarText", "white")
                    font.family: Theme.value("fonts", "ui", "Tahoma")
                    font.pixelSize: Math.max(9, Theme.size("fontSize", 11) - 2)
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: {
                    if (containsMouse) {
                        root.showTip(
                            clockCell,
                            Qt.formatDate(clock.date, Qt.locale().dateFormat(Locale.LongFormat)),
                            "")
                    } else {
                        root.hideTip(clockCell)
                    }
                }
                onDoubleClicked: root.openClockProperties()
            }
        }
    }

    function openClockProperties() {
        // Vista/7 calendar flyout deferred (GenerationPolicy clockFlyout). XP and
        // fallback: Date and Time Properties via KDE clock KCM.
        Quickshell.execDetached(["kcmshell6", "kcm_clock"])
    }
}
