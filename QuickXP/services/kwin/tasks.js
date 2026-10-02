// Runs inside KWin. KWin does not offer the foreign-toplevel protocol to
// Quickshell, so this publishes the taskbar windows. Clicks are applied by
// tasks-apply.js (one-shot, kicked from TasksBridge.Command).
const seen = new Set()
let dirty = true
let publishTimer = null

function shown(window) {
    if (!window || window.deleted || window.skipTaskbar)
        return false
    if (window.dock || window.desktopWindow || window.popupWindow || window.tooltip || window.notification || window.splash)
        return false
    return window.normalWindow || window.dialog
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

function schedulePublish() {
    dirty = true
    if (publishTimer === null) {
        publishTimer = new QTimer()
        publishTimer.interval = 200
        publishTimer.timeout.connect(() => {
            publishTimer.stop()
            if (!dirty)
                return
            dirty = false
            publish()
        })
    }
    // Restart so bursts of caption/active changes coalesce.
    publishTimer.stop()
    publishTimer.start()
}

function watch(window) {
    if (!window || seen.has(window))
        return
    seen.add(window)
    const bump = () => { schedulePublish() }
    try { window.captionChanged.connect(bump) } catch (error) {}
    try { window.minimizedChanged.connect(bump) } catch (error) {}
    try { window.maximizedChanged.connect(bump) } catch (error) {}
    try { window.activeChanged.connect(bump) } catch (error) {}
    try { window.desktopFileNameChanged.connect(bump) } catch (error) {}
    try {
        window.closed.connect(() => {
            seen.delete(window)
            schedulePublish()
        })
    } catch (error) {}
}

workspace.windowList().forEach(watch)
workspace.windowAdded.connect(window => {
    watch(window)
    schedulePublish()
})
workspace.windowRemoved.connect(() => { schedulePublish() })

// Meta/Windows → Start is owned by ShellBridge + kglobalaccel (org.quickxp.start.desktop).
// Do not registerShortcut("Meta") here: on Plasma 6.1+ it steals the binding for
// invokeShortcut but often does not fire on a real modifier-only keypress.

schedulePublish()
