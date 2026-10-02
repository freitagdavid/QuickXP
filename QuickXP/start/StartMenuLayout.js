.pragma library

// Pure Start menu layout selection for host + qmltestrunner.
// Classic single-column only when effective startMenu generation is "classic".
// XP dual-column is used for xp / vista / win7 until Epic 3 search Start ships.

function useClassic(startMenuGeneration) {
    var raw = String(startMenuGeneration === undefined || startMenuGeneration === null
        ? ""
        : startMenuGeneration).trim().toLowerCase()
    return raw === "classic"
}

function useXpDualColumn(startMenuGeneration) {
    return !useClassic(startMenuGeneration)
}
