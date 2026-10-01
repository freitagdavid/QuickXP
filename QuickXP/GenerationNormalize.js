.pragma library

// Pure generation string normalization for shell policy and qmltestrunner.
// Keep aliases in sync with GenerationPolicy.qml normalize().

var GENERATIONS = ["classic", "xp", "vista", "win7"]

function normalize(value, fallback) {
    var raw = String(value === undefined || value === null ? "" : value).trim().toLowerCase()
    if (raw === "windows xp" || raw === "winxp")
        return "xp"
    if (raw === "windows vista" || raw === "winvista")
        return "vista"
    if (raw === "windows 7" || raw === "windows7" || raw === "win 7")
        return "win7"
    if (raw === "windows classic" || raw === "winclassic")
        return "classic"
    for (var i = 0; i < GENERATIONS.length; ++i) {
        if (GENERATIONS[i] === raw)
            return raw
    }
    return fallback === undefined ? "xp" : fallback
}
