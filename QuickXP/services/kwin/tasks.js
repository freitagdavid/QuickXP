// Runs inside KWin. KWin does not offer the foreign-toplevel protocol to
// Quickshell, so this publishes the taskbar windows and applies clicks.
const seen = new Set()
let dirty = true

function shown(window) {
    if (!window || window.deleted || window.skipTaskbar)
        return false
    if (window.dock || window.desktopWindow || window.popupWindow || window.tooltip || window.notification || window.splash)
        return false
    return window.normalWindow || window.dialog
}

function sameId(window, id) {
    const raw = String(window.internalId)
    const wanted = String(id)
    return raw === wanted || raw.replace(/[{}]/g, "") === wanted.replace(/[{}]/g, "")
}

function findWindow(id) {
    let found = null
    workspace.windowList().forEach(window => {
        if (found === null && sameId(window, id))
            found = window
    })
    return found
}

function flag(window, name, fallback) {
    try {
        const value = window[name]
        if (value === undefined || value === null)
            return fallback
        return !!value
    } catch (error) {
        return fallback
    }
}

function isMaximized(window) {
    try {
        const mode = window.maximizeMode
        if (mode === undefined || mode === null)
            return false
        if (typeof mode === "number")
            return mode !== 0
        const text = String(mode)
        return text !== "0" && text !== "MaximizeRestore" && text !== ""
    } catch (error) {
        return false
    }
}

function activate(window) {
    window.minimized = false
    // WindowsRunner ids are "0_" plus the window uuid. Activating that way
    // restores a minimized window and gives it focus.
    callDBus("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1", "Run", "0_" + String(window.internalId), "")
}

function applyCommand(command) {
    const window = findWindow(command.id)
    if (!window)
        return
    const action = command.action
    if (action === "minimize") {
        window.minimized = true
        return
    }
    if (action === "close") {
        window.closeWindow()
        return
    }
    if (action === "maximize") {
        window.minimized = false
        window.setMaximize(true, true)
        return
    }
    if (action === "restore") {
        window.minimized = false
        window.setMaximize(false, false)
        return
    }
    if (action === "move" || action === "resize") {
        window.minimized = false
        try { workspace.activeWindow = window } catch (error) {}
        try {
            if (action === "move")
                workspace.slotWindowMove()
            else
                workspace.slotWindowResize()
        } catch (error) {
            console.warn("quickxp-tasks: " + action + " failed: " + error)
        }
        return
    }
    activate(window)
}

function publish() {
    const windows = []
    workspace.windowList().forEach(window => {
        if (!shown(window))
            return
        const appId = window.desktopFileName || window.resourceClass || ""
        windows.push({
            id: String(window.internalId),
            title: window.caption || "",
            appId: String(appId).replace(/\.desktop$/, ""),
            minimized: !!window.minimized,
            active: !!window.active,
            maximized: isMaximized(window),
            closeable: flag(window, "closeable", true),
            minimizable: flag(window, "minimizable", true),
            maximizable: flag(window, "maximizable", true),
            moveable: flag(window, "moveable", true),
            resizeable: flag(window, "resizeable", true)
        })
    })
    callDBus("org.quickxp.Tasks", "/org/quickxp/Tasks", "org.quickxp.Tasks", "SetWindows", JSON.stringify(windows))
}

function watch(window) {
    if (!window || seen.has(window))
        return
    seen.add(window)
    const bump = () => { dirty = true }
    try { window.captionChanged.connect(bump) } catch (error) {}
    try { window.minimizedChanged.connect(bump) } catch (error) {}
    try { window.maximizedChanged.connect(bump) } catch (error) {}
    try { window.activeChanged.connect(bump) } catch (error) {}
    try { window.desktopFileNameChanged.connect(bump) } catch (error) {}
    try {
        window.closed.connect(() => {
            seen.delete(window)
            dirty = true
        })
    } catch (error) {}
}

workspace.windowList().forEach(watch)
workspace.windowAdded.connect(window => {
    watch(window)
    dirty = true
})
workspace.windowRemoved.connect(() => { dirty = true })

const timer = new QTimer()
timer.interval = 200
timer.timeout.connect(() => {
    if (dirty) {
        dirty = false
        publish()
    }
    callDBus("org.quickxp.Tasks", "/org/quickxp/Tasks", "org.quickxp.Tasks", "TakeCommands", payload => {
        if (!payload || payload === "[]")
            return
        try {
            JSON.parse(payload).forEach(applyCommand)
        } catch (error) {
            console.warn("quickxp-tasks: commands failed: " + error)
        }
        dirty = true
    })
})
timer.start()
