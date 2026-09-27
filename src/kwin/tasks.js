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

function applyCommand(command) {
    const window = findWindow(command.id)
    if (!window)
        return
    if (command.action === "minimize") {
        window.minimized = true
        return
    }
    window.minimized = false
    // WindowsRunner ids are "0_" plus the window uuid. Activating that way
    // restores a minimized window and gives it focus.
    callDBus("org.kde.KWin", "/WindowsRunner", "org.kde.krunner1", "Run", "0_" + String(window.internalId), "")
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
            active: !!window.active
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
