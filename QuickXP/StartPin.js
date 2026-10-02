.pragma library

// XP Start pinned apps list (persisted as JSON string array of desktop ids).

function parsePins(raw) {
  try {
    const value = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(value))
      return []
    const out = []
    const seen = {}
    for (let i = 0; i < value.length; ++i) {
      const id = String(value[i] || "").trim()
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

function pinsJson(ids) {
  return JSON.stringify(Array.isArray(ids) ? ids : [])
}

function hasCategory(entry, name) {
  if (!entry)
    return false
  const cats = entry.categories
  if (!Array.isArray(cats))
    return false
  const want = String(name || "").toLowerCase()
  for (let i = 0; i < cats.length; ++i) {
    if (String(cats[i] || "").toLowerCase() === want)
      return true
  }
  return false
}

// Default Internet + E-mail handlers from desktop categories (STA-05).
function defaultPinIds(applications) {
  const apps = Array.isArray(applications) ? applications : []
  let browser = ""
  let email = ""
  for (let i = 0; i < apps.length; ++i) {
    const app = apps[i]
    if (!app || !app.id)
      continue
    if (!browser && (hasCategory(app, "WebBrowser") || hasCategory(app, "Network")))
      browser = String(app.id)
    if (!email && (hasCategory(app, "Email") || hasCategory(app, "Office")))
      email = String(app.id)
    if (browser && email)
      break
  }
  // Prefer a clearer browser pick: rescan for WebBrowser only.
  for (let j = 0; j < apps.length; ++j) {
    if (hasCategory(apps[j], "WebBrowser") && apps[j].id) {
      browser = String(apps[j].id)
      break
    }
  }
  for (let k = 0; k < apps.length; ++k) {
    if (hasCategory(apps[k], "Email") && apps[k].id) {
      email = String(apps[k].id)
      break
    }
  }
  const out = []
  if (browser)
    out.push(browser)
  if (email && email !== browser)
    out.push(email)
  return out
}

function pin(raw, entryId) {
  const id = String(entryId || "").trim()
  if (!id)
    return String(raw || "[]")
  const ids = parsePins(raw)
  if (ids.indexOf(id) >= 0)
    return pinsJson(ids)
  ids.push(id)
  return pinsJson(ids)
}

function unpin(raw, entryId) {
  const id = String(entryId || "").trim()
  const ids = parsePins(raw)
  const next = []
  for (let i = 0; i < ids.length; ++i) {
    if (ids[i] !== id)
      next.push(ids[i])
  }
  return pinsJson(next)
}

function move(raw, fromIndex, toIndex) {
  const ids = parsePins(raw)
  const from = Number(fromIndex)
  const to = Number(toIndex)
  if (from < 0 || from >= ids.length || to < 0 || to >= ids.length || from === to)
    return pinsJson(ids)
  const item = ids.splice(from, 1)[0]
  ids.splice(to, 0, item)
  return pinsJson(ids)
}

function isPinned(raw, entryId) {
  return parsePins(raw).indexOf(String(entryId || "").trim()) >= 0
}
