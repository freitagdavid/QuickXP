.pragma library

// Pure taskband entry builders for TaskList + qmltestrunner.
// Keep in sync with Settings Config.options.groupButtons / iconsOnly.

function groupKey(win) {
    if (win === null || win === undefined)
        return ""
    var appId = win.appId !== undefined && win.appId !== null ? String(win.appId) : ""
    if (appId !== "")
        return "a:" + appId
    if (win.kwin && win.windowId !== undefined && win.windowId !== null)
        return "k:" + String(win.windowId)
    if (win.__key !== undefined && win.__key !== null)
        return "u:" + String(win.__key)
    return "t:" + String(win.title || "")
}

function appLabel(win) {
    if (win === null || win === undefined)
        return ""
    if (win.appName !== undefined && win.appName !== null && String(win.appName) !== "")
        return String(win.appName)
    var appId = win.appId !== undefined && win.appId !== null ? String(win.appId) : ""
    if (appId !== "") {
        var slash = appId.lastIndexOf(".")
        if (slash >= 0 && slash < appId.length - 1)
            return appId.slice(slash + 1)
        return appId
    }
    return win.title ? String(win.title) : ""
}

function needsPaging(count, bandWidth, minButtonWidth, spacing) {
    count = Number(count) || 0
    bandWidth = Number(bandWidth) || 0
    minButtonWidth = Number(minButtonWidth) || 48
    spacing = Number(spacing) || 0
    if (count <= 0 || bandWidth <= 0)
        return false
    var needed = count * minButtonWidth + spacing * Math.max(0, count - 1)
    return needed > bandWidth
}

function pickRepresentative(windows) {
    if (!windows || windows.length === 0)
        return null
    for (var i = 0; i < windows.length; ++i) {
        var w = windows[i]
        if (w && w.activated && !w.minimized)
            return w
    }
    for (var j = 0; j < windows.length; ++j) {
        if (windows[j] && windows[j].activated)
            return windows[j]
    }
    return windows[0]
}

function windowIdentity(win) {
    if (win === null || win === undefined)
        return ""
    if (win.kwin && win.windowId !== undefined && win.windowId !== null)
        return "k:" + String(win.windowId)
    if (win.__key !== undefined && win.__key !== null)
        return "u:" + String(win.__key)
    // Live toplevel: object string is stable for the same instance.
    return "w:" + String(win)
}

function entryFromWindows(windows) {
    var list = windows && windows.length ? windows.slice() : []
    var rep = pickRepresentative(list)
    var count = list.length
    var title = ""
    if (count > 1) {
        // Count is rendered as a badge on the button; title is the app name.
        title = appLabel(rep)
    } else if (rep) {
        title = rep.title ? String(rep.title) : appLabel(rep)
    }
    var entry = {
        kind: count > 1 ? "group" : "window",
        appId: rep && rep.appId ? String(rep.appId) : "",
        title: title,
        count: count,
        windows: list,
        representative: rep
    }
    // Single buttons must stay unique even when appId matches; groups key by app.
    if (count > 1)
        entry.key = groupKey(rep)
    else
        entry.key = windowIdentity(rep) || groupKey(rep) || ("t:" + title)
    return entry
}

function flatEntries(windows) {
    var out = []
    if (!windows)
        return out
    for (var i = 0; i < windows.length; ++i)
        out.push(entryFromWindows([windows[i]]))
    return out
}

function combineByApp(windows) {
    var order = []
    var bags = {}
    if (!windows)
        return []
    for (var i = 0; i < windows.length; ++i) {
        var win = windows[i]
        var key = groupKey(win)
        if (!bags[key]) {
            bags[key] = []
            order.push(key)
        }
        bags[key].push(win)
    }
    var out = []
    for (var j = 0; j < order.length; ++j)
        out.push(entryFromWindows(bags[order[j]]))
    return out
}

function buildEntries(windows, options) {
    var opts = options || {}
    var groupButtons = !!opts.groupButtons
    var iconsOnly = !!opts.iconsOnly
    var bandWidth = opts.bandWidth
    var minButtonWidth = opts.minButtonWidth
    var spacing = opts.spacing
    var list = Array.isArray(windows) ? windows : []

    if (!groupButtons)
        return flatEntries(list)

    // Icons-only + grouping → always combine. Labeled → only when crowded.
    if (iconsOnly || needsPaging(list.length, bandWidth, minButtonWidth, spacing))
        return combineByApp(list)
    return flatEntries(list)
}

function entryKey(entry) {
    if (!entry)
        return ""
    if (entry.key !== undefined && entry.key !== null && String(entry.key) !== "")
        return String(entry.key)
    var rep = entry.representative
    if (entry.kind === "group" || (entry.count !== undefined && Number(entry.count) > 1))
        return groupKey(rep) || ("a:" + String(entry.appId || ""))
    if (rep)
        return windowIdentity(rep) || groupKey(rep)
    if (entry.appId)
        return "a:" + String(entry.appId)
    return "t:" + String(entry.title || "")
}

function stampEntry(entry) {
    if (!entry)
        return entry
    entry.key = entryKey(entry)
    return entry
}

function stampEntries(entries) {
    var out = []
    var list = Array.isArray(entries) ? entries : []
    for (var i = 0; i < list.length; ++i)
        out.push(stampEntry(list[i]))
    return out
}

// Diff stamped entry lists into ListModel ops. update = same key, mutate props;
// remove/insert/reorder cover membership changes without full model reset.
function diffEntries(prev, next) {
    var oldList = Array.isArray(prev) ? prev : []
    var newList = Array.isArray(next) ? next : []
    var oldIndex = {}
    for (var i = 0; i < oldList.length; ++i) {
        var ok = entryKey(oldList[i])
        if (ok)
            oldIndex[ok] = i
    }
    var newIndex = {}
    for (var j = 0; j < newList.length; ++j) {
        var nk = entryKey(newList[j])
        if (nk)
            newIndex[nk] = j
    }

    var removes = []
    for (var r = oldList.length - 1; r >= 0; --r) {
        var rk = entryKey(oldList[r])
        if (!rk || newIndex[rk] === undefined)
            removes.push({ index: r, key: rk })
    }

    var inserts = []
    var updates = []
    for (var n = 0; n < newList.length; ++n) {
        var entry = newList[n]
        var key = entryKey(entry)
        if (!key)
            continue
        if (oldIndex[key] === undefined)
            inserts.push({ index: n, key: key, entry: entry })
        else
            updates.push({ key: key, entry: entry, from: oldIndex[key], to: n })
    }

    return {
        removes: removes,
        inserts: inserts,
        updates: updates,
        sameLength: oldList.length === newList.length && removes.length === 0 && inserts.length === 0
    }
}

function pageSlice(entries, page, perPage, paging) {
    var all = Array.isArray(entries) ? entries : []
    if (!all.length)
        return []
    if (!paging)
        return all.slice()
    var start = Math.max(0, (Number(page) || 0) * (Number(perPage) || 1))
    var end = Math.min(all.length, start + Math.max(1, Number(perPage) || 1))
    return all.slice(start, end)
}
