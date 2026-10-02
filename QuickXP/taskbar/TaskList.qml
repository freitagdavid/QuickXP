import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.QuickXP
import "../TaskbandModel.js" as TaskbandModel

Item {
    id: root

    clip: true

    // KWin does not export zwlr-foreign-toplevel to clients other than
    // Plasma, so on KDE the window list comes from a KWin script (TasksService).
    readonly property bool useKwin: TasksService.useKwin
    readonly property var kwinTasks: TasksService.kwinTasks

    // Stamped entry list for paging math; Repeater uses pageModel (stable keys).
    property var entries: []
    // Full entry objects live here — ListModel cannot hold nested JS maps/lists
    // as a role without type poisoning (List ↔ VariantMap).
    property var entryStore: ({})
    property int entryStoreRev: 0

    ListModel {
        id: pageModel
    }

    function entryForKey(key: string): var {
        const _ = root.entryStoreRev
        if (!key)
            return null
        const hit = root.entryStore[key]
        return hit !== undefined ? hit : null
    }

    Connections {
        target: TasksService
        function onKwinTasksChanged() {
            if (root.useKwin)
                root.rebuildBand()
        }
        function onPreviewReply(serial, path) {
            // Bridge replies follow a capture/refresh — bust Image cache.
            root.previewReady(serial, path, true)
            groupStrip.previewReady(serial, path)
        }
    }

    readonly property bool groupButtons: !!Config.options.groupButtons
    readonly property bool iconsOnly: !!Config.options.iconsOnly

    readonly property int spacing: 3
    readonly property int maxButtonWidth: 160
    // Floor before the Luna caps collide. Past this the band pages.
    readonly property int minButtonWidth: 48
    // Icons-only buttons are square: width matches the taskband height.
    readonly property int iconButtonWidth: Math.max(24, Math.round(height))
    readonly property int slotWidth: root.iconsOnly ? root.iconButtonWidth : root.minButtonWidth
    property int page: 0
    property string trackedFocusKey: ""

    function enrichWindow(row) {
        const appId = row.appId || ""
        const resolved = appId !== "" ? AppCatalog.resolveApp(appId) : { name: "", icon: "" }
        row.appName = resolved.name || ""
        row.iconName = resolved.icon || ""
        return row
    }

    function collectWindows() {
        if (root.useKwin) {
            const shown = []
            const rows = root.kwinTasks
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                shown.push(root.enrichWindow({
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
                }))
            }
            return shown
        }

        const all = ToplevelManager.toplevels.values
        const shown = []
        for (let i = 0; i < all.length; ++i) {
            const toplevel = all[i]
            if (toplevel.parent != null)
                continue
            shown.push(toplevel)
        }
        return shown
    }

    // Binding trigger for the foreign-toplevel backend (ObjectModel identity).
    readonly property var toplevelSnapshot: {
        if (root.useKwin)
            return null
        return root.collectWindows()
    }

    function syncListModel(model, nextEntries) {
        const next = TaskbandModel.stampEntries(nextEntries)
        const store = ({})
        const keys = []
        for (let j = 0; j < next.length; ++j) {
            const entry = next[j]
            const key = TaskbandModel.entryKey(entry)
            if (!key)
                continue
            store[key] = entry
            keys.push(key)
        }
        root.entryStore = store
        root.entryStoreRev++

        // Drop a poisoned model from older builds that stored nested `entry` roles.
        if (model.count > 0) {
            const row0 = model.get(0)
            if (row0.key === undefined || row0.key === null) {
                model.clear()
            }
        }

        let sameOrder = model.count === keys.length
        if (sameOrder) {
            for (let i = 0; i < keys.length; ++i) {
                if (String(model.get(i).key) !== keys[i]) {
                    sameOrder = false
                    break
                }
            }
        }
        // Title/active-only updates: keep Repeater delegates; refresh via entryStore.
        if (sameOrder)
            return

        for (let i = model.count - 1; i >= 0; --i) {
            const key = String(model.get(i).key || "")
            let keep = false
            for (let j = 0; j < keys.length; ++j) {
                if (keys[j] === key) {
                    keep = true
                    break
                }
            }
            if (!keep)
                model.remove(i)
        }
        for (let n = 0; n < keys.length; ++n) {
            const key = keys[n]
            let found = -1
            for (let i = 0; i < model.count; ++i) {
                if (String(model.get(i).key) === key) {
                    found = i
                    break
                }
            }
            if (found === -1) {
                model.insert(n, { key: key })
            } else if (found !== n) {
                model.move(found, n, 1)
            }
        }
        while (model.count > keys.length)
            model.remove(model.count - 1)
    }

    function rebuildBand() {
        const wins = root.collectWindows()
        const built = TaskbandModel.buildEntries(wins, {
            groupButtons: root.groupButtons,
            iconsOnly: root.iconsOnly,
            bandWidth: root.width,
            minButtonWidth: root.slotWidth,
            spacing: root.spacing
        })
        root.entries = TaskbandModel.stampEntries(Array.isArray(built) ? built : [])
        root.syncPageModel()
        root.syncPage()
    }

    function syncPageModel() {
        const slice = TaskbandModel.pageSlice(
            root.entries, root.page, root.perPage, root.paging)
        root.syncListModel(pageModel, slice)
    }

    onToplevelSnapshotChanged: if (!root.useKwin)
        root.rebuildBand()
    onGroupButtonsChanged: root.rebuildBand()
    onIconsOnlyChanged: root.rebuildBand()
    onWidthChanged: root.rebuildBand()
    onSlotWidthChanged: root.rebuildBand()
    onPerPageChanged: root.syncPageModel()
    onPagingChanged: root.syncPageModel()
    Component.onCompleted: root.rebuildBand()

    function sendCommand(windowId, action) {
        TasksService.sendCommand(windowId, action)
    }

    function requestBridgePreview(serial, windowId) {
        TasksService.requestPreview(serial, windowId)
    }

    readonly property real pagerWidth: height / 2
    readonly property bool paging: {
        const list = entries
        const count = list && list.length ? list.length : 0
        if (count === 0 || width <= 0)
            return false
        const needed = count * slotWidth + spacing * Math.max(0, count - 1)
        return needed > width
    }
    readonly property int perPage: {
        const list = entries
        const total = list && list.length ? list.length : 0
        if (!paging)
            return Math.max(1, total)
        const available = Math.max(0, width - pagerWidth - spacing)
        const slot = slotWidth + spacing
        return Math.max(1, Math.floor((available + spacing) / slot))
    }
    readonly property int pageCount: {
        const list = entries
        const total = list && list.length ? list.length : 0
        if (!paging)
            return 1
        return Math.max(1, Math.ceil(total / perPage))
    }
    readonly property int buttonWidth: {
        const list = entries
        const count = list && list.length ? list.length : 0
        if (count === 0 || width <= 0)
            return 0
        // Icons-only: square tiles matching band height.
        if (root.iconsOnly)
            return root.iconButtonWidth
        if (paging)
            return minButtonWidth
        const gaps = spacing * Math.max(0, count - 1)
        const share = (width - gaps) / count
        return Math.max(minButtonWidth, Math.min(maxButtonWidth, Math.floor(share)))
    }
    function windowKey(win) {
        if (win === null || win === undefined)
            return ""
        if (win.kwin)
            return "k:" + String(win.windowId)
        return "w:" + String(win)
    }

    function entryContainsFocus(entry) {
        if (!entry || !entry.windows || !entry.windows.length)
            return false
        for (let i = 0; i < entry.windows.length; ++i) {
            const win = entry.windows[i]
            if (win && win.activated && !win.minimized)
                return true
        }
        return false
    }

    // Follow a newly focused window onto its page. A manual page change
    // stays put until focus moves again.
    function syncPage() {
        const all = entries
        if (!all || !all.length) {
            trackedFocusKey = ""
            if (page !== 0)
                page = 0
            return
        }
        let focusKey = ""
        let focusIndex = -1
        for (let i = 0; i < all.length; ++i) {
            const entry = all[i]
            if (root.entryContainsFocus(entry)) {
                focusIndex = i
                const rep = entry.representative
                focusKey = root.windowKey(rep)
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

    onPageCountChanged: syncPage()
    onPageChanged: {
        taskMenu.dismiss()
        groupMenu.dismiss()
        root.cancelGroupPreviewImmediate()
        dismissPreview()
        root.syncPageModel()
    }

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
            model: pageModel

            delegate: TaskButton {
                required property string key

                readonly property var resolved: root.entryForKey(key)

                taskList: root
                entry: resolved
                toplevel: resolved && resolved.representative ? resolved.representative : null
                iconsOnly: root.iconsOnly
                width: root.buttonWidth
                height: row.height
            }
        }
    }

    // Group strip is a hover preview, not a "menu" — exclude it so hover can keep it open.
    readonly property bool taskMenuOpen: taskMenu.visible || groupMenu.visible

    property int previewSerial: 0
    property var previewButton: null
    property var previewToplevel: null
    property bool previewOnButton: false

    property var groupPreviewButton: null
    property var groupPreviewEntry: null
    property bool groupPreviewOnButton: false

    function requestPreview(button, toplevel) {
        root.cancelGroupPreviewImmediate()
        previewOnButton = true
        previewCloseTimer.stop()
        if (previewButton !== button) {
            previewPopup.dismiss()
            previewSerial = TasksService.nextPreviewSerial()
        } else if (previewPopup.visible || previewTimer.running) {
            // Keep showing / waiting; refresh target after entryStore sync.
            previewToplevel = toplevel
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
        previewSerial = TasksService.nextPreviewSerial()
        previewPopup.dismiss()
    }

    function closePreviewIfIdle() {
        if (previewOnButton || previewPopup.hovered)
            return
        dismissPreview()
    }

    function requestGroupPreview(button, entry) {
        if (!entry || !entry.windows || entry.windows.length <= 1)
            return
        root.dismissPreview()
        groupMenu.dismiss()
        groupPreviewOnButton = true
        groupStripCloseTimer.stop()
        const sameButton = groupPreviewButton === button
        const sameKey = sameButton && groupPreviewEntry
            && TaskbandModel.entryKey(groupPreviewEntry) === TaskbandModel.entryKey(entry)
        if (sameKey && (groupStrip.visible || groupStripTimer.running)) {
            groupPreviewEntry = entry
            if (groupStrip.visible)
                groupStrip.windows = entry.windows
            return
        }
        groupPreviewButton = button
        groupPreviewEntry = entry
        groupStripTimer.restart()
    }

    function cancelGroupPreview() {
        groupPreviewOnButton = false
        groupStripCloseTimer.restart()
    }

    function cancelGroupPreviewImmediate() {
        groupPreviewOnButton = false
        groupStripTimer.stop()
        groupStripCloseTimer.stop()
        groupPreviewButton = null
        groupPreviewEntry = null
        groupStrip.dismiss()
    }

    function closeGroupStripIfIdle() {
        if (groupPreviewOnButton || groupStrip.hovered)
            return
        root.cancelGroupPreviewImmediate()
    }

    function showGroupStrip() {
        if (!groupPreviewOnButton || groupPreviewEntry === null || groupPreviewButton === null)
            return
        if (taskMenu.visible)
            return
        groupMenu.dismiss()
        groupStrip.windows = groupPreviewEntry.windows
        groupStrip.anchorItem = groupPreviewButton
        groupStrip.open()
    }

    function previewCachePath(windowId: string): string {
        const safe = String(windowId).replace(/[^A-Za-z0-9._-]+/g, "_") || "unknown"
        const state = String(TasksService.stateFile)
        const slash = state.lastIndexOf("/")
        if (slash < 0)
            return ""
        return state.substring(0, slash) + "/quickxp-preview-w-" + safe + ".png"
    }

    function startCapture() {
        if (!previewOnButton || previewToplevel === null || taskMenu.visible)
            return
        if (!previewToplevel.kwin) {
            if (previewButton !== null)
                previewButton.showFallbackTip()
            return
        }
        const serial = TasksService.nextPreviewSerial()
        previewSerial = serial
        const windowId = previewToplevel.windowId
        // Wait for bridge PREVIEW reply (warm cache or fresh capture). Pointing
        // Image at the cache path before the file exists spams "Cannot open".
        root.requestBridgePreview(serial, windowId)
    }

    function previewReady(serial, path, bustCache) {
        if (serial !== previewSerial)
            return
        if (!previewOnButton && !previewPopup.hovered)
            return
        if (!path || path === "-") {
            if (previewButton !== null && !previewPopup.visible)
                previewButton.showFallbackTip()
            return
        }
        if (previewButton !== null)
            previewButton.hideTip()
        previewPopup.title = previewToplevel !== null ? (previewToplevel.title || "") : ""
        previewPopup.closeEnabled = previewToplevel === null || previewToplevel.closeable !== false
        const samePath = previewPopup.imagePath === path
        previewPopup.imagePath = path
        if (bustCache === true || !samePath)
            previewPopup.imageNonce = Date.now()
        previewPopup.anchorItem = previewButton
        previewPopup.open()
    }

    function activatePreviewWindow() {
        const target = previewToplevel
        dismissPreview()
        if (target === null)
            return
        root.activateWindow(target)
    }

    function closePreviewWindow() {
        const target = previewToplevel
        dismissPreview()
        if (target === null)
            return
        root.closeWindow(target)
    }

    function closeWindow(target) {
        if (target === null || target === undefined)
            return
        if (target.kwin) {
            root.sendCommand(target.windowId, "close")
            return
        }
        if (typeof target.close === "function")
            target.close()
    }

    function closeGroupStripWindow(target) {
        if (target === null || target === undefined)
            return
        root.closeWindow(target)
        groupStrip.removeWindow(target)
        // Keep hover sticky while the strip remains open.
        groupPreviewOnButton = true
        groupStripCloseTimer.stop()
    }

    function activateWindow(target) {
        if (target === null || target === undefined)
            return
        if (target.kwin) {
            root.sendCommand(target.windowId, "activate")
            return
        }
        target.minimized = false
        if (typeof target.activate === "function")
            target.activate()
    }

    function openTaskMenu(anchor, toplevel, keepHoverPopups) {
        if (!keepHoverPopups) {
            dismissPreview()
            root.cancelGroupPreviewImmediate()
        } else {
            // Keep peek/strip open under the system menu; pause grab so opening
            // the menu does not auto-close the preview via focus loss.
            previewOnButton = true
            groupPreviewOnButton = true
            previewCloseTimer.stop()
            groupStripCloseTimer.stop()
            previewPopup.grabFocus = false
            groupStrip.grabFocus = false
        }
        groupMenu.dismiss()
        taskMenu.dismiss()
        taskMenu.toplevel = toplevel
        taskMenu.anchorItem = anchor
        taskMenu.open()
    }

    function restorePreviewGrab() {
        // Peeks stay grab-less; only click menus use grabFocus.
        if (previewPopup.visible)
            previewPopup.grabFocus = false
        if (groupStrip.visible)
            groupStrip.grabFocus = false
    }

    function cycleGroup(entry) {
        if (!entry || !entry.windows || entry.windows.length === 0)
            return
        const next = TaskbandModel.nextInGroup(entry.windows)
        if (next)
            root.activateWindow(next)
    }

    function openGroupPopup(button, entry) {
        if (!entry || !entry.windows || entry.windows.length <= 1)
            return
        dismissPreview()
        taskMenu.dismiss()
        // Icons-only / modern: strip is already the hover UI — keep or open it.
        // Labeled XP: open the title list (e.g. from a future affordance).
        if (root.iconsOnly) {
            groupMenu.dismiss()
            groupPreviewOnButton = true
            groupPreviewButton = button
            groupPreviewEntry = entry
            groupStrip.windows = entry.windows
            groupStrip.anchorItem = button
            if (!groupStrip.visible)
                groupStrip.open()
            return
        }
        root.cancelGroupPreviewImmediate()
        groupMenu.windows = entry.windows
        groupMenu.anchorItem = button
        groupMenu.open()
    }

    function runMenuAction(action) {
        const target = taskMenu.toplevel
        if (target === null)
            return
        if (target.kwin) {
            root.sendCommand(target.windowId, action)
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
        onVisibleChanged: {
            if (!visible)
                root.restorePreviewGrab()
        }
    }

    TaskGroupMenu {
        id: groupMenu
        onActivated: toplevel => root.activateWindow(toplevel)
    }

    TaskGroupStrip {
        id: groupStrip
        taskList: root
        onActivated: toplevel => {
            root.cancelGroupPreviewImmediate()
            root.activateWindow(toplevel)
        }
        onCloseClicked: toplevel => root.closeGroupStripWindow(toplevel)
        onContextMenuRequested: (toplevel, anchorItem) => {
            root.openTaskMenu(anchorItem, toplevel, true)
        }
        onHoverLeft: {
            if (!taskMenu.visible)
                groupStripCloseTimer.restart()
        }
        onClosedOut: {
            // Outside click / grab loss — sync TaskList state.
            if (groupStrip.visible)
                return
            root.cancelGroupPreviewImmediate()
        }
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

    Timer {
        id: groupStripTimer
        interval: 400
        onTriggered: root.showGroupStrip()
    }

    Timer {
        id: groupStripCloseTimer
        interval: 250
        onTriggered: root.closeGroupStripIfIdle()
    }

    TaskPreview {
        id: previewPopup
        onHoverLeft: {
            if (!taskMenu.visible)
                previewCloseTimer.restart()
        }
        onActivated: root.activatePreviewWindow()
        onCloseClicked: root.closePreviewWindow()
        onContextMenuRequested: {
            if (previewToplevel === null)
                return
            root.openTaskMenu(previewPopup, previewToplevel, true)
        }
        onClosedOut: {
            if (previewPopup.visible)
                return
            root.dismissPreview()
        }
    }
}
