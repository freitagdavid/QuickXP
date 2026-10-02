// Apply helpers for one-shot command scripts. TasksBridge prepends
// `var commands = [...];` and appends `commands.forEach(applyCommand);`
// Keep find/apply in sync with the former tasks.js command path.
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

function activate(window) {
    // Prefer sync activation: one-shot scripts are stopped/unloaded quickly, so
    // async callDBus(WindowsRunner) alone often never completes.
    window.minimized = false
    try {
        workspace.activeWindow = window
    } catch (error) {
        console.warn("quickxp-tasks-apply: activeWindow failed: " + error)
    }
    try {
        if (typeof workspace.raiseWindow === "function")
            workspace.raiseWindow(window)
    } catch (error) {}
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
            console.warn("quickxp-tasks-apply: " + action + " failed: " + error)
        }
        return
    }
    activate(window)
}
