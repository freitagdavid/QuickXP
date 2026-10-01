// Classic Start personalized menus: hide rarely used apps until expand (SMS-23).

.pragma library

function parseUsage(raw) {
  try {
    const value = JSON.parse(String(raw || "{}"))
    return value && typeof value === "object" ? value : {}
  } catch (error) {
    return {}
  }
}

function usageJson(map) {
  return JSON.stringify(map && typeof map === "object" ? map : {})
}

function bumpUsage(raw, entryId) {
  const id = String(entryId || "")
  if (!id)
    return String(raw || "{}")
  const map = parseUsage(raw)
  map[id] = (Number(map[id]) || 0) + 1
  return usageJson(map)
}

function scoreFor(map, entryId) {
  return Number(map[String(entryId || "")] || 0)
}

// Fold infrequently used app leaves behind an expand sentinel.
function personalizeFolder(node, usageRaw, threshold, expanded) {
  if (!node || node.kind !== "folder")
    return node
  const usage = parseUsage(usageRaw)
  const thr = Math.max(0, Number(threshold) || 0)
  const kids = Array.isArray(node.children) ? node.children : []
  const kept = []
  const hidden = []
  for (let i = 0; i < kids.length; ++i) {
    const child = kids[i]
    if (!child)
      continue
    if (child.kind === "folder") {
      kept.push(personalizeFolder(child, usageRaw, thr, expanded))
      continue
    }
    if (child.kind === "app") {
      const score = scoreFor(usage, child.entryId || child.id)
      if (!expanded && score < thr)
        hidden.push(child)
      else
        kept.push(child)
      continue
    }
    kept.push(child)
  }
  if (!expanded && hidden.length) {
    kept.push({
      kind: "action",
      id: "expand:" + String(node.id || "folder"),
      action: "expand-personalized",
      folderId: String(node.id || ""),
      label: ">>",
      icon: "",
      mnemonic: "",
      children: [],
      hiddenCount: hidden.length
    })
  }
  return {
    kind: node.kind,
    id: node.id,
    label: node.label,
    icon: node.icon || "",
    mnemonic: node.mnemonic || "",
    children: kept,
    entryId: node.entryId || "",
    action: node.action || "",
    uri: node.uri || "",
    isNew: !!node.isNew,
    hasNew: !!node.hasNew
  }
}
