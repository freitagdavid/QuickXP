import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    clip: true

    // KWin does not export zwlr-foreign-toplevel to clients other than
    // Plasma, so on KDE the window list comes from a KWin script.
    readonly property bool useKwin: {
        const desktop = String(Quickshell.env("XDG_CURRENT_DESKTOP") || "")
        const session = String(Quickshell.env("KDE_FULL_SESSION") || "")
        return desktop.toUpperCase().indexOf("KDE") !== -1 || session === "true"
    }
    readonly property string stateFile: Quickshell.statePath("quickxp-tasks.json")
    readonly property string scriptFile: Quickshell.shellPath("QuickXP/services/kwin/tasks.js")

    property var kwinTasks: []

    function applyTasks(text) {
        try {
            const parsed = JSON.parse(text)
            root.kwinTasks = Array.isArray(parsed) ? parsed : []
        } catch (error) {
            console.warn("QuickXP tasks:", error)
        }
    }

    readonly property int spacing: 3
    readonly property int maxButtonWidth: 160
    // Floor before the Luna caps collide. Past this the band pages.
    readonly property int minButtonWidth: 48 
    property int page: 0
    property string trackedFocusKey: ""

    readonly property var windows: {
        if (root.useKwin) {
            const shown = []
            const rows = root.kwinTasks
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                shown.push({
                    kwin: true,
                    windowId: row.id,
                    title: row.title || "",
                    appId: row.appId || "",
                    activated: !!row.active,
                    minimized: !!row.minimized,
                    maximized: !!row.maximized,
                    closeable: row.closeable !== false,
                    minimizable: row.minimizable !== false,
                    maximizable: row.maximizable !== false,
                    moveable: row.moveable !== false,
                    resizeable: row.resizeable !== false,
                    parent: null
                })
            }
            return shown
        }

        const all = ToplevelManager.toplevels.values
        const shown = []
        for (let i = 0; i < all.length; ++i) {
            const toplevel = all[i]
            if (toplevel.parent == null)
                shown.push(toplevel)
        }
        return shown
    }

    Process {
        id: bridge

        running: root.useKwin
        command: ["/usr/bin/python3", Quickshell.shellPath("QuickXP/services/TasksBridge.py"), root.stateFile, root.scriptFile]

        stderr: SplitParser {
            onRead: data => console.warn("QuickXP tasks:", data.trim())
        }

        onStarted: taskFile.reload()
    }

    FileView {
        id: taskFile

        watchChanges: true
        printErrors: false
        blockLoading: false
        path: root.useKwin ? root.stateFile : ""

        onFileChanged: reload()
        onLoaded: root.applyTasks(text())
    }
    readonly property real pagerWidth: height / 2
    readonly property bool paging: {
        const count = windows.length
        if (count === 0 || width <= 0)
            return false
        const needed = count * minButtonWidth + spacing * Math.max(0, count - 1)
        return needed > width
    }
    readonly property int perPage: {
        if (!paging)
            return Math.max(1, windows.length)
        const available = Math.max(0, width - pagerWidth - spacing)
        const slot = minButtonWidth + spacing
        return Math.max(1, Math.floor((available + spacing) / slot))
    }
    readonly property int pageCount: {
        if (!paging)
            return 1
        return Math.max(1, Math.ceil(windows.length / perPage))
    }
    readonly property int buttonWidth: {
        const count = windows.length
        if (count === 0 || width <= 0)
            return 0
        if (paging)
            return minButtonWidth
        const gaps = spacing * Math.max(0, count - 1)
        const share = (width - gaps) / count
        return Math.max(minButtonWidth, Math.min(maxButtonWidth, Math.floor(share)))
    }
    readonly property var pageWindows: {
        const all = windows
        if (!paging)
            return all
        const start = page * perPage
        const shown = []
        const end = Math.min(all.length, start + perPage)
        for (let i = start; i < end; ++i)
            shown.push(all[i])
        return shown
    }

    function windowKey(win) {
        if (win === null || win === undefined)
            return ""
        if (win.kwin)
            return "k:" + String(win.windowId)
        return "w:" + String(win)
    }

    // Follow a newly focused window onto its page. A manual page change
    // stays put until focus moves again.
    function syncPage() {
        const all = windows
        let focusKey = ""
        let focusIndex = -1
        for (let i = 0; i < all.length; ++i) {
            const win = all[i]
            if (win.activated && !win.minimized) {
                focusIndex = i
                focusKey = windowKey(win)
                break
            }
        }

        let next = page
        if (focusKey !== "" && focusKey !== trackedFocusKey) {
            trackedFocusKey = focusKey
            if (paging)
                next = Math.floor(focusIndex / perPage)
        } else if (focusKey === "") {
            trackedFocusKey = ""
        }

        const last = Math.max(0, pageCount - 1)
        if (next > last)
            next = last
        if (next < 0)
            next = 0
        if (page !== next)
            page = next
    }

    onWindowsChanged: syncPage()
    onPagingChanged: syncPage()
    onPerPageChanged: syncPage()
    onPageCountChanged: syncPage()
    onPageChanged: {
        taskMenu.dismiss()
        dismissPreview()
    }
    Component.onCompleted: syncPage()

    TaskPager {
        id: pager

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.paging
        width: root.paging ? implicitWidth : 0
        upEnabled: root.page > 0
        downEnabled: root.page < root.pageCount - 1
        onUpClicked: root.page = Math.max(0, root.page - 1)
        onDownClicked: root.page = Math.min(root.pageCount - 1, root.page + 1)
    }

    Row {
        id: row

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: pager.left
        anchors.rightMargin: root.paging ? root.spacing : 0
        spacing: root.spacing

        Repeater {
            model: root.pageWindows

            delegate: TaskButton {
                required property var modelData

                taskList: root
                toplevel: modelData
                width: root.buttonWidth
                height: row.height
            }
        }
    }

    readonly property bool taskMenuOpen: taskMenu.visible

    property int previewSerial: 0
    property var previewButton: null
    property var previewToplevel: null
    property bool previewOnButton: false

    function requestPreview(button, toplevel) {
        previewOnButton = true
        previewCloseTimer.stop()
        if (previewButton !== button) {
            previewPopup.dismiss()
            previewSerial += 1
            if (capture.running)
                capture.running = false
        } else if (previewPopup.visible) {
            return
        }
        previewButton = button
        previewToplevel = toplevel
        previewTimer.restart()
    }

    function cancelPreviewButton() {
        previewOnButton = false
        previewCloseTimer.restart()
    }

    function dismissPreview() {
        previewOnButton = false
        previewTimer.stop()
        previewCloseTimer.stop()
        previewSerial += 1
        if (capture.running)
            capture.running = false
        previewPopup.dismiss()
    }

    function closePreviewIfIdle() {
        if (previewOnButton || previewPopup.hovered)
            return
        dismissPreview()
    }

    function startCapture() {
        if (!previewOnButton || previewToplevel === null || taskMenu.visible)
            return
        if (!previewToplevel.kwin) {
            if (previewButton !== null)
                previewButton.showFallbackTip()
            return
        }
        const serial = ++previewSerial
        const windowId = previewToplevel.windowId
        capture.pendingSerial = serial
        capture.running = false
        Qt.callLater(() => {
            if (serial !== previewSerial || !previewOnButton)
                return
            capture.command = [
                "qdbus6", "org.quickxp.Tasks", "/org/quickxp/Tasks",
                "org.quickxp.Tasks.Preview", windowId
            ]
            capture.running = true
        })
    }

    function previewReady(serial, path) {
        if (serial !== previewSerial)
            return
        if (!previewOnButton && !previewPopup.hovered)
            return
        if (path === "") {
            if (previewButton !== null)
                previewButton.showFallbackTip()
            return
        }
        if (previewButton !== null)
            previewButton.hideTip()
        previewPopup.title = previewToplevel !== null ? (previewToplevel.title || "") : ""
        previewPopup.closeEnabled = previewToplevel === null || previewToplevel.closeable !== false
        previewPopup.imagePath = path
        previewPopup.anchorItem = previewButton
        previewPopup.open()
    }

    function activatePreviewWindow() {
        const target = previewToplevel
        dismissPreview()
        if (target === null)
            return
        if (target.kwin) {
            Quickshell.execDetached([
                "qdbus6", "org.quickxp.Tasks", "/org/quickxp/Tasks",
                "org.quickxp.Tasks.Command", target.windowId, "activate"
            ])
            return
        }
        target.minimized = false
        if (typeof target.activate === "function")
            target.activate()
    }

    function closePreviewWindow() {
        const target = previewToplevel
        dismissPreview()
        if (target === null)
            return
        if (target.kwin) {
            Quickshell.execDetached([
                "qdbus6", "org.quickxp.Tasks", "/org/quickxp/Tasks",
                "org.quickxp.Tasks.Command", target.windowId, "close"
            ])
            return
        }
        if (typeof target.close === "function")
            target.close()
    }

    function openTaskMenu(button, toplevel) {
        dismissPreview()
        taskMenu.dismiss()
        taskMenu.toplevel = toplevel
        taskMenu.anchorItem = button
        taskMenu.open()
    }

    function runMenuAction(action) {
        const target = taskMenu.toplevel
        if (target === null)
            return
        if (target.kwin) {
            Quickshell.execDetached([
                "qdbus6", "org.quickxp.Tasks", "/org/quickxp/Tasks",
                "org.quickxp.Tasks.Command", target.windowId, action
            ])
            return
        }
        if (action === "close" && typeof target.close === "function")
            target.close()
        else if (action === "minimize")
            target.minimized = true
        else if (action === "maximize")
            target.maximized = true
        else if (action === "restore") {
            target.minimized = false
            target.maximized = false
            target.activate()
        }
    }

    TaskMenu {
        id: taskMenu
        onChosen: action => root.runMenuAction(action)
    }

    Timer {
        id: previewTimer
        interval: 400
        onTriggered: root.startCapture()
    }

    Timer {
        id: previewCloseTimer
        interval: 250
        onTriggered: root.closePreviewIfIdle()
    }

    Process {
        id: capture

        property int pendingSerial: 0

        stdout: SplitParser {
            onRead: data => root.previewReady(capture.pendingSerial, data.trim())
        }

        stderr: SplitParser {
            onRead: data => console.warn("QuickXP preview:", data.trim())
        }
    }

    TaskPreview {
        id: previewPopup
        onHoverLeft: previewCloseTimer.restart()
        onActivated: root.activatePreviewWindow()
        onCloseClicked: root.closePreviewWindow()
    }
}
