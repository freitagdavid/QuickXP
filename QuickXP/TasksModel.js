.pragma library

// Pure TasksService helpers for qmltestrunner (no Quickshell).

function parseWindowsJson(text) {
    if (text === null || text === undefined)
        return []
    var raw = String(text).trim()
    if (!raw)
        return []
    try {
        var parsed = JSON.parse(raw)
        return Array.isArray(parsed) ? parsed : []
    } catch (error) {
        return []
    }
}

function formatCommandLine(windowId, action) {
    var id = String(windowId || "").trim()
    var act = String(action || "").trim()
    if (!id || !act)
        return ""
    return "COMMAND " + id + " " + act + "\n"
}

function formatPreviewRequest(serial, windowId) {
    var id = String(windowId || "").trim()
    if (!id)
        return ""
    return "PREVIEW " + String(serial) + " " + id + "\n"
}

function formatShowDesktop() {
    return "SHOWDESKTOP\n"
}

function useKwinSession(desktop, kdeFullSession) {
    var name = String(desktop || "").toUpperCase()
    var full = String(kdeFullSession || "")
    if (full === "true")
        return true
    if (name.indexOf("KDE") !== -1)
        return true
    if (name.indexOf("QUICKXP") !== -1)
        return true
    return false
}

function parsePreviewReply(line) {
    var text = String(line || "").trim()
    if (!text)
        return null
    var parts = text.split(/\s+/)
    if (parts.length < 2 || parts[0] !== "PREVIEW")
        return null
    var serial = Number(parts[1])
    var path = parts.length >= 3 && parts[2] !== "-" ? parts[2] : ""
    return { serial: serial, path: path }
}
