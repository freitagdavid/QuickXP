.pragma library

// Pure helpers for AppCatalog (qmltestrunner-friendly).

function isLaunchable(entry) {
    if (entry === undefined || entry === null)
        return false
    if (entry.noDisplay === true)
        return false
    var name = entry.name
    if (name === undefined || name === null)
        return false
    return String(name).trim() !== ""
}

function filterLaunchable(entries) {
    var out = []
    if (entries === undefined || entries === null)
        return out
    var list = entries
    // ObjectModel / array-like
    var count = list.count !== undefined ? list.count : list.length
    if (count === undefined)
        return out
    for (var i = 0; i < count; ++i) {
        var entry = list.get !== undefined ? list.get(i) : list[i]
        if (isLaunchable(entry))
            out.push(entry)
    }
    return out
}

function nameMatches(entry, query) {
    if (!isLaunchable(entry))
        return false
    var q = String(query === undefined || query === null ? "" : query).trim().toLowerCase()
    if (q === "")
        return true
    var name = String(entry.name).toLowerCase()
    if (name.indexOf(q) !== -1)
        return true
    var generic = entry.genericName
    if (generic !== undefined && generic !== null && String(generic).toLowerCase().indexOf(q) !== -1)
        return true
    return false
}

function filterByQuery(entries, query) {
    var launchable = filterLaunchable(entries)
    var out = []
    for (var i = 0; i < launchable.length; ++i) {
        if (nameMatches(launchable[i], query))
            out.push(launchable[i])
    }
    return out
}

function compareByName(a, b) {
    var left = String(a && a.name ? a.name : "").toLowerCase()
    var right = String(b && b.name ? b.name : "").toLowerCase()
    if (left < right)
        return -1
    if (left > right)
        return 1
    return 0
}

function sortByName(entries) {
    var copy = entries.slice()
    copy.sort(compareByName)
    return copy
}
