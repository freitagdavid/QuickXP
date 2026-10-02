.pragma library

// Classic Start cascades use Win9x beige chrome + large icons.
// XP dual-column All Programs / places flyouts use white StartGroup chrome.

function normalize(style) {
  return String(style === undefined || style === null ? "" : style).trim().toLowerCase()
}

function isXp(style) {
  const raw = normalize(style)
  return raw === "xp" || raw === "startgroup" || raw === "luna"
}

function isClassic(style) {
  return !isXp(style)
}

function rowHeight(style) {
  return isXp(style) ? 22 : 32
}

function iconSize(style) {
  return isXp(style) ? 16 : 32
}
