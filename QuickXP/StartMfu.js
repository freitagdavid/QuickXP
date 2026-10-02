.pragma library

// XP Start most-frequently-used scoring with time decay (STA-10–14).

function parseScores(raw) {
  try {
    const value = JSON.parse(String(raw || "{}"))
    return value && typeof value === "object" ? value : {}
  } catch (error) {
    return {}
  }
}

function scoresJson(map) {
  return JSON.stringify(map && typeof map === "object" ? map : {})
}

function parseIdList(raw) {
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

function idListJson(ids) {
  return JSON.stringify(Array.isArray(ids) ? ids : [])
}

function nowMs() {
  return Date.now()
}

// Exponential decay: score' = score * 0.5^(days/halfLifeDays) + 1
function bumpScore(raw, entryId, halfLifeDays, atMs) {
  const id = String(entryId || "").trim()
  if (!id)
    return String(raw || "{}")
  const map = parseScores(raw)
  const half = Math.max(0.1, Number(halfLifeDays) || 7)
  const now = Number(atMs) || nowMs()
  const prev = map[id] && typeof map[id] === "object" ? map[id] : {}
  const oldScore = Number(prev.score) || 0
  const last = Number(prev.last) || now
  const days = Math.max(0, (now - last) / 86400000)
  const decayed = oldScore * Math.pow(0.5, days / half)
  map[id] = { score: decayed + 1, last: now }
  return scoresJson(map)
}

function removeFromList(raw, entryId) {
  const id = String(entryId || "").trim()
  const map = parseScores(raw)
  if (map[id] !== undefined)
    delete map[id]
  return scoresJson(map)
}

function clearList() {
  return "{}"
}

function exclude(rawExcluded, entryId) {
  const id = String(entryId || "").trim()
  if (!id)
    return String(rawExcluded || "[]")
  const ids = parseIdList(rawExcluded)
  if (ids.indexOf(id) >= 0)
    return idListJson(ids)
  ids.push(id)
  return idListJson(ids)
}

function rankedIds(rawScores, rawExcluded, pinnedIds, limit, atMs) {
  const map = parseScores(rawScores)
  const excluded = {}
  const ex = parseIdList(rawExcluded)
  for (let i = 0; i < ex.length; ++i)
    excluded[ex[i]] = true
  const pinned = {}
  const pins = Array.isArray(pinnedIds) ? pinnedIds : []
  for (let j = 0; j < pins.length; ++j)
    pinned[String(pins[j] || "")] = true

  const half = 7
  const now = Number(atMs) || nowMs()
  const rows = []
  for (const id in map) {
    if (!id || excluded[id] || pinned[id])
      continue
    const prev = map[id] && typeof map[id] === "object" ? map[id] : {}
    const oldScore = Number(prev.score) || 0
    const last = Number(prev.last) || now
    const days = Math.max(0, (now - last) / 86400000)
    const score = oldScore * Math.pow(0.5, days / half)
    if (score <= 0)
      continue
    rows.push({ id: id, score: score })
  }
  rows.sort(function(a, b) {
    if (b.score !== a.score)
      return b.score - a.score
    return a.id < b.id ? -1 : (a.id > b.id ? 1 : 0)
  })
  const max = Math.max(0, Number(limit) || 0)
  const out = []
  for (let k = 0; k < rows.length && out.length < max; ++k)
    out.push(rows[k].id)
  return out
}
