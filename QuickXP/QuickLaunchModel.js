.pragma library

// Quick Launch list helpers (desktop ids + show-desktop sentinel).

var SHOW_DESKTOP_ID = "quickxp:show-desktop"

function showDesktopId() {
  return SHOW_DESKTOP_ID
}

function parseIds(raw) {
  try {
    var value = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(value))
      return []
    var out = []
    var seen = {}
    for (var i = 0; i < value.length; ++i) {
      var id = String(value[i] || "").trim()
      if (!id || seen[id])
        continue
      seen[id] = true
      out.push(id)
    }
    return out
  } catch (error) {
    return []
  }
}

function idsJson(ids) {
  return JSON.stringify(Array.isArray(ids) ? ids : [])
}

function isShowDesktop(id) {
  return String(id || "") === SHOW_DESKTOP_ID
}

function defaultIds(applications) {
  var out = [SHOW_DESKTOP_ID]
  var apps = Array.isArray(applications) ? applications : []
  var browser = ""
  for (var i = 0; i < apps.length; ++i) {
    var app = apps[i]
    if (!app || !app.id)
      continue
    var cats = app.categories
    if (!Array.isArray(cats))
      continue
    for (var c = 0; c < cats.length; ++c) {
      if (String(cats[c] || "").toLowerCase() === "webbrowser") {
        browser = String(app.id)
        break
      }
    }
    if (browser)
      break
  }
  if (browser)
    out.push(browser)
  return out
}

function insert(raw, entryId, index) {
  var ids = parseIds(raw)
  var id = String(entryId || "").trim()
  if (!id)
    return idsJson(ids)
  var next = []
  for (var i = 0; i < ids.length; ++i) {
    if (ids[i] !== id)
      next.push(ids[i])
  }
  var at = Number(index)
  if (isNaN(at) || at < 0 || at > next.length)
    at = next.length
  // Keep show-desktop first when present.
  if (id === SHOW_DESKTOP_ID) {
    next.unshift(id)
  } else {
    var sd = next.indexOf(SHOW_DESKTOP_ID)
    if (sd === 0 && at === 0)
      at = 1
    next.splice(at, 0, id)
  }
  return idsJson(next)
}

function remove(raw, entryId) {
  var id = String(entryId || "").trim()
  if (!id || id === SHOW_DESKTOP_ID)
    return String(raw || "[]")
  var ids = parseIds(raw)
  var next = []
  for (var i = 0; i < ids.length; ++i) {
    if (ids[i] !== id)
      next.push(ids[i])
  }
  return idsJson(next)
}

function move(raw, fromIndex, toIndex) {
  var ids = parseIds(raw)
  var from = Number(fromIndex)
  var to = Number(toIndex)
  if (isNaN(from) || isNaN(to) || from < 0 || from >= ids.length)
    return idsJson(ids)
  if (to < 0)
    to = 0
  if (to >= ids.length)
    to = ids.length - 1
  if (ids[from] === SHOW_DESKTOP_ID || ids[to] === SHOW_DESKTOP_ID)
    return idsJson(ids)
  var item = ids.splice(from, 1)[0]
  ids.splice(to, 0, item)
  // Ensure show-desktop stays at 0 if present.
  var sd = ids.indexOf(SHOW_DESKTOP_ID)
  if (sd > 0) {
    ids.splice(sd, 1)
    ids.unshift(SHOW_DESKTOP_ID)
  }
  return idsJson(ids)
}

function iconSizeForHeight(taskbarHeight) {
  var h = Number(taskbarHeight) || 30
  if (h >= 48)
    return 32
  if (h >= 36)
    return 24
  return 16
}

function slotWidth(iconSize) {
  var s = Number(iconSize) || 16
  return s + 8
}

function visibleCount(total, availableWidth, iconSize, reserveChevron) {
  var n = Number(total) || 0
  if (n <= 0)
    return 0
  var slot = slotWidth(iconSize)
  var width = Number(availableWidth) || 0
  if (width <= 0)
    return 0
  var chevron = reserveChevron ? slot : 0
  var fit = Math.floor(Math.max(0, width - chevron) / slot)
  if (fit >= n)
    return n
  if (fit < 1)
    return reserveChevron ? 0 : Math.min(1, n)
  return Math.max(0, Math.min(n, fit))
}

function visibleSlice(ids, availableWidth, iconSize) {
  var list = Array.isArray(ids) ? ids : parseIds(ids)
  var n = list.length
  var fit = visibleCount(n, availableWidth, iconSize, false)
  if (fit >= n)
    return { visible: list.slice(), overflow: [] }
  // Need chevron room.
  fit = visibleCount(n, availableWidth, iconSize, true)
  return {
    visible: list.slice(0, fit),
    overflow: list.slice(fit)
  }
}
