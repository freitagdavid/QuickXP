.pragma library

// Vista/7 Start search ranking (apps, recent docs, settings) for qmltestrunner.

function normalizeQuery(query) {
    return String(query === undefined || query === null ? "" : query).trim().toLowerCase()
}

function escClearsQuery(query) {
    return normalizeQuery(query) !== ""
}

function defaultSettingsIndex() {
    return [
        {
            id: "setting:theme",
            kind: "setting",
            tab: "theme",
            label: "Theme",
            icon: "preferences-desktop-theme",
            keywords: ["theme", "appearance", "display", "color", "msstyles"]
        },
        {
            id: "setting:taskbar",
            kind: "setting",
            tab: "taskbar",
            label: "Taskbar",
            icon: "preferences-system-windows",
            keywords: ["taskbar", "task bar", "grouping", "icons"]
        },
        {
            id: "setting:start",
            kind: "setting",
            tab: "start",
            label: "Start Menu",
            icon: "start-here",
            keywords: ["start", "start menu", "pinned", "mfu", "programs"]
        },
        {
            id: "setting:debug",
            kind: "setting",
            tab: "debug",
            label: "Debugging",
            icon: "applications-development",
            keywords: ["debug", "debugging"]
        },
        {
            id: "setting:control-panel",
            kind: "setting",
            tab: "theme",
            label: "Control Panel",
            icon: "preferences-system",
            keywords: ["control panel", "settings", "display properties"]
        }
    ]
}

function parseScoreMap(raw) {
    var out = {}
    if (raw === undefined || raw === null)
        return out
    if (typeof raw === "object" && !Array.isArray(raw)) {
        var keys = Object.keys(raw)
        for (var i = 0; i < keys.length; ++i) {
            var id = String(keys[i] || "").trim()
            if (!id)
                continue
            var val = raw[id]
            if (val !== undefined && val !== null && typeof val === "object")
                out[id] = Number(val.score) || 0
            else
                out[id] = Number(val) || 0
        }
        return out
    }
    try {
        var parsed = JSON.parse(String(raw || "{}"))
        return parseScoreMap(parsed)
    } catch (error) {
        return out
    }
}

function matchQuality(text, query) {
    var t = String(text === undefined || text === null ? "" : text).toLowerCase()
    if (!query || !t)
        return 0
    if (t.indexOf(query) === 0)
        return 2
    if (t.indexOf(query) !== -1)
        return 1
    return 0
}

function bestMatchQuality(parts, query) {
    var best = 0
    for (var i = 0; i < parts.length; ++i) {
        var q = matchQuality(parts[i], query)
        if (q > best)
            best = q
    }
    return best
}

function pinIdSet(pinIds) {
    var out = {}
    if (!pinIds || pinIds.length === undefined)
        return out
    for (var i = 0; i < pinIds.length; ++i) {
        var id = String(pinIds[i] || "").trim()
        if (id)
            out[id] = true
    }
    return out
}

function pinBoost(entryId, pinIdsOrSet) {
    var id = String(entryId || "").trim()
    if (!id || !pinIdsOrSet)
        return 0
    // O(1) map from pinIdSet(); keep array fallback for older callers/tests.
    if (pinIdsOrSet.length === undefined)
        return pinIdsOrSet[id] ? 1000 : 0
    for (var i = 0; i < pinIdsOrSet.length; ++i) {
        if (String(pinIdsOrSet[i] || "").trim() === id)
            return 1000
    }
    return 0
}

function matchQualityLower(textL, query) {
    var t = String(textL === undefined || textL === null ? "" : textL)
    if (!query || !t)
        return 0
    if (t.indexOf(query) === 0)
        return 2
    if (t.indexOf(query) !== -1)
        return 1
    return 0
}

function bestMatchQualityLower(partsL, query) {
    var best = 0
    for (var i = 0; i < partsL.length; ++i) {
        var q = matchQualityLower(partsL[i], query)
        if (q > best)
            best = q
    }
    return best
}

function buildAppSearchIndex(apps) {
    var out = []
    var count = entryCount(apps)
    for (var i = 0; i < count; ++i) {
        var entry = entryAt(apps, i)
        if (!entry || entry.noDisplay === true)
            continue
        var name = entry.name
        if (name === undefined || name === null || String(name).trim() === "")
            continue
        out.push({
            entry: entry,
            nameL: String(name).toLowerCase(),
            genericL: String(entry.genericName || "").toLowerCase(),
            idL: String(entry.id || "").toLowerCase()
        })
    }
    return out
}

function filterAppsIndexed(index, query) {
    var q = normalizeQuery(query)
    var out = []
    if (!index || q === "")
        return out
    for (var i = 0; i < index.length; ++i) {
        var row = index[i]
        if (!row)
            continue
        var quality = bestMatchQualityLower([row.nameL, row.genericL, row.idL], q)
        if (quality <= 0)
            continue
        out.push({
            entry: row.entry,
            quality: quality
        })
    }
    return out
}

function mfuBoost(entryId, mfuScores) {
    var id = String(entryId || "").trim()
    if (!id || !mfuScores)
        return 0
    var score = Number(mfuScores[id]) || 0
    if (score <= 0)
        return 0
    return Math.min(200, score * 10)
}

function qualityBoost(quality) {
    if (quality >= 2)
        return 50
    if (quality >= 1)
        return 10
    return 0
}

function compareRanked(a, b) {
    if (b.score !== a.score)
        return b.score - a.score
    var left = String(a.label || "").toLowerCase()
    var right = String(b.label || "").toLowerCase()
    if (left < right)
        return -1
    if (left > right)
        return 1
    return 0
}

function entryAt(entries, index) {
    if (!entries)
        return null
    // Prefer length indexing for real arrays; ObjectModel uses count + get.
    if (typeof entries.length === "number" && entries.get === undefined)
        return entries[index]
    if (entries.get !== undefined)
        return entries.get(index)
    return entries[index]
}

function entryCount(entries) {
    if (!entries)
        return 0
    if (typeof entries.length === "number" && entries.get === undefined)
        return entries.length
    if (entries.count !== undefined)
        return entries.count
    if (typeof entries.length === "number")
        return entries.length
    return 0
}

function filterApps(entries, query) {
    var q = normalizeQuery(query)
    var out = []
    if (!entries || q === "")
        return out
    var count = entryCount(entries)
    for (var i = 0; i < count; ++i) {
        var entry = entryAt(entries, i)
        if (!entry || entry.noDisplay === true)
            continue
        var name = entry.name
        if (name === undefined || name === null || String(name).trim() === "")
            continue
        var quality = bestMatchQuality([
            name,
            entry.genericName,
            entry.id
        ], q)
        if (quality <= 0)
            continue
        out.push({
            entry: entry,
            quality: quality
        })
    }
    return out
}

function filterDocuments(recentItems, query) {
    var q = normalizeQuery(query)
    var out = []
    if (!recentItems || q === "")
        return out
    for (var i = 0; i < recentItems.length; ++i) {
        var item = recentItems[i]
        if (!item)
            continue
        var label = String(item.label || "")
        var uri = String(item.uri || "")
        var quality = bestMatchQuality([label, uri], q)
        if (quality <= 0)
            continue
        out.push({
            item: item,
            quality: quality
        })
    }
    return out
}

function filterSettings(settings, query) {
    var q = normalizeQuery(query)
    var out = []
    var list = settings && settings.length !== undefined ? settings : defaultSettingsIndex()
    if (q === "")
        return out
    for (var i = 0; i < list.length; ++i) {
        var row = list[i]
        if (!row)
            continue
        var parts = [row.label, row.tab, row.id]
        var keywords = row.keywords || []
        for (var k = 0; k < keywords.length; ++k)
            parts.push(keywords[k])
        var quality = bestMatchQuality(parts, q)
        if (quality <= 0)
            continue
        out.push({
            row: row,
            quality: quality
        })
    }
    return out
}

function isSelectable(node) {
    return !!(node && node.kind && node.kind !== "header")
}

function moveFocus(results, index, delta) {
    if (!results || results.length === 0)
        return -1
    var step = delta < 0 ? -1 : 1
    var i = Number(index)
    if (isNaN(i))
        i = -1
    if (i < 0)
        i = step > 0 ? -1 : results.length
    var guard = 0
    while (guard < results.length) {
        i += step
        if (i < 0 || i >= results.length)
            return -1
        if (isSelectable(results[i]))
            return i
        guard++
    }
    return -1
}

function firstSelectableIndex(results) {
    return moveFocus(results, -1, 1)
}

// Build ranked Start search rows. Empty query → [].
// ctx: { apps|appIndex, recentItems, pinIds|pinSet, mfuScores|rawMfuScores, settings, limit }
function buildResults(query, ctx) {
    var q = normalizeQuery(query)
    if (q === "")
        return []
    ctx = ctx || {}
    var pinSet = ctx.pinSet
    if (!pinSet)
        pinSet = pinIdSet(ctx.pinIds || [])
    var mfuScores = ctx.mfuScores
    if (!mfuScores)
        mfuScores = parseScoreMap(ctx.rawMfuScores)
    var limit = Number(ctx.limit)
    if (!limit || limit < 1)
        limit = 40

    var appIndex = ctx.appIndex
    if (!appIndex)
        appIndex = buildAppSearchIndex(ctx.apps)

    var programs = []
    var appHits = filterAppsIndexed(appIndex, q)
    for (var a = 0; a < appHits.length; ++a) {
        var hit = appHits[a]
        var entry = hit.entry
        var entryId = String(entry.id || entry.name || "")
        var label = String(entry.name || entryId)
        var score = qualityBoost(hit.quality) + pinBoost(entryId, pinSet) + mfuBoost(entryId, mfuScores)
        programs.push({
            kind: "app",
            id: entryId,
            entryId: entryId,
            label: label,
            icon: String(entry.icon || ""),
            score: score,
            category: "programs"
        })
    }
    programs.sort(compareRanked)

    var documents = []
    var docHits = filterDocuments(ctx.recentItems, q)
    for (var d = 0; d < docHits.length; ++d) {
        var dh = docHits[d]
        var item = dh.item
        var docLabel = String(item.label || item.uri || "Document")
        documents.push({
            kind: "action",
            action: "open-uri",
            uri: String(item.uri || ""),
            id: String(item.id || ("doc:" + d)),
            label: docLabel,
            icon: String(item.icon || "text-x-generic"),
            score: qualityBoost(dh.quality),
            category: "documents"
        })
    }
    documents.sort(compareRanked)

    var settings = []
    var setHits = filterSettings(ctx.settings, q)
    for (var s = 0; s < setHits.length; ++s) {
        var sh = setHits[s]
        var row = sh.row
        settings.push({
            kind: "setting",
            tab: String(row.tab || ""),
            id: String(row.id || ("setting:" + row.tab)),
            label: String(row.label || row.tab || "Settings"),
            icon: String(row.icon || "preferences-system"),
            score: qualityBoost(sh.quality),
            category: "settings"
        })
    }
    settings.sort(compareRanked)

    var out = []
    function pushGroup(headerLabel, headerId, rows) {
        if (!rows.length)
            return
        out.push({
            kind: "header",
            id: headerId,
            label: headerLabel
        })
        for (var i = 0; i < rows.length; ++i) {
            if (out.length >= limit + 3)
                return
            out.push(rows[i])
        }
    }

    pushGroup("Programs", "header:programs", programs)
    pushGroup("Documents", "header:documents", documents)
    pushGroup("Settings", "header:settings", settings)

    // Trim selectable overflow while keeping headers only when they still have children.
    if (out.length <= limit)
        return out
    var trimmed = []
    var selectable = 0
    for (var t = 0; t < out.length; ++t) {
        var node = out[t]
        if (node.kind === "header") {
            // Peek ahead: only keep header if a selectable follows within remaining budget.
            var hasChild = false
            for (var n = t + 1; n < out.length; ++n) {
                if (out[n].kind === "header")
                    break
                if (selectable < limit) {
                    hasChild = true
                    break
                }
            }
            if (hasChild)
                trimmed.push(node)
            continue
        }
        if (selectable >= limit)
            break
        trimmed.push(node)
        selectable++
    }
    return trimmed
}
