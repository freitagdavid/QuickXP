// Helpers for Classic Start "highlight newly installed" tracking.

.pragma library

function parseIdList(raw) {
  try {
    const value = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(value))
      return []
    return value.map(function(v) { return String(v || "") }).filter(function(v) { return !!v })
  } catch (error) {
    return []
  }
}

function toIdListJson(ids) {
  const list = Array.isArray(ids) ? ids : []
  const uniq = []
  const seen = {}
  for (let i = 0; i < list.length; ++i) {
    const id = String(list[i] || "")
    if (!id || seen[id])
      continue
    seen[id] = true
    uniq.push(id)
  }
  uniq.sort()
  return JSON.stringify(uniq)
}

function idSet(ids) {
  const set = {}
  const list = Array.isArray(ids) ? ids : []
  for (let i = 0; i < list.length; ++i)
    set[String(list[i] || "")] = true
  return set
}

// First run: seed seen with all current ids (nothing highlighted yet).
// Later: ids not in seen are new.
function reconcile(seenIds, currentIds, seeded) {
  const current = Array.isArray(currentIds) ? currentIds.map(String) : []
  const seen = parseIdList(typeof seenIds === "string" ? seenIds : toIdListJson(seenIds))
  if (!seeded || !seen.length) {
    return {
      seenJson: toIdListJson(current),
      newIds: [],
      seeded: true
    }
  }
  const set = idSet(seen)
  const neu = []
  for (let i = 0; i < current.length; ++i) {
    const id = current[i]
    if (id && !set[id])
      neu.push(id)
  }
  return {
    seenJson: toIdListJson(seen),
    newIds: neu,
    seeded: true
  }
}

function markSeen(seenJson, entryId) {
  const id = String(entryId || "")
  if (!id)
    return String(seenJson || "[]")
  const list = parseIdList(seenJson)
  if (list.indexOf(id) >= 0)
    return toIdListJson(list)
  list.push(id)
  return toIdListJson(list)
}

function markNodeTree(node, newIdSet) {
  if (!node)
    return node
  const copy = {
    kind: node.kind,
    id: node.id,
    label: node.label,
    icon: node.icon || "",
    mnemonic: node.mnemonic || "",
    children: [],
    entryId: node.entryId || "",
    action: node.action || "",
    uri: node.uri || "",
    isNew: false
  }
  if (node.kind === "app") {
    const eid = String(node.entryId || node.id || "")
    copy.isNew = !!(eid && newIdSet[eid])
  }
  const kids = Array.isArray(node.children) ? node.children : []
  for (let i = 0; i < kids.length; ++i)
    copy.children.push(markNodeTree(kids[i], newIdSet))
  if (node.kind === "folder") {
    for (let j = 0; j < copy.children.length; ++j) {
      if (copy.children[j].isNew || copy.children[j].hasNew) {
        copy.hasNew = true
        break
      }
    }
  }
  return copy
}
