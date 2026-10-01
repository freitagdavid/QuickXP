.pragma library

// Pure helpers for per-feature override values (choice generations or toggle).

function normalizeToggle(value, onGenerations) {
    if (value === undefined || value === null)
        return ""
    var raw = String(value).trim().toLowerCase()
    if (raw === "")
        return ""
    if (raw === "enabled" || raw === "enable" || raw === "on" || raw === "true" || raw === "1")
        return "enabled"
    if (raw === "disabled" || raw === "disable" || raw === "off" || raw === "false" || raw === "0")
        return "disabled"
    var onGens = onGenerations !== undefined && onGenerations !== null
        ? onGenerations
        : ["vista", "win7"]
    for (var i = 0; i < onGens.length; ++i) {
        if (onGens[i] === raw)
            return "enabled"
    }
    if (raw === "classic" || raw === "xp")
        return "disabled"
    return ""
}

function withFollowChoice(choices, followLabel) {
    var follow = {
        id: "",
        label: followLabel !== undefined && followLabel !== null && followLabel !== ""
            ? followLabel
            : "Use shell default"
    }
    var opts = choices !== undefined && choices !== null ? choices : []
    return [follow].concat(opts)
}
