.pragma library

// Pure Start menu layout selection for host + qmltestrunner.
// Classic single-column only when effective startMenu generation is "classic".
// XP dual-column is used for xp / vista / win7; search chrome is a separate toggle.

function useClassic(startMenuGeneration) {
    var raw = String(startMenuGeneration === undefined || startMenuGeneration === null
        ? ""
        : startMenuGeneration).trim().toLowerCase()
    return raw === "classic"
}

function useXpDualColumn(startMenuGeneration) {
    return !useClassic(startMenuGeneration)
}

// startSearchEnabled is GenerationPolicy.featureEnabled("startSearch") (bool).
function useStartSearch(startSearchEnabled) {
    return startSearchEnabled === true
}
