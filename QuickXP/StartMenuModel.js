// Pure helpers for Classic Start Programs trees (category + shared node shape).

.pragma library

var CATEGORY_LABELS = {
  AudioVideo: "Sound & Video",
  Audio: "Sound & Video",
  Video: "Sound & Video",
  Development: "Development",
  Education: "Education",
  Game: "Games",
  Graphics: "Graphics",
  Network: "Internet",
  Office: "Office",
  Science: "Science",
  Settings: "Settings",
  System: "System Tools",
  Utility: "Accessories",
  Accessibility: "Accessibility"
}

var CATEGORY_ORDER = [
  "Utility",
  "Development",
  "Education",
  "Game",
  "Graphics",
  "Network",
  "AudioVideo",
  "Office",
  "Science",
  "Settings",
  "System",
  "Accessibility"
]

var SKIP_CATEGORIES = {
  Core: true,
  Qt: true,
  GTK: true,
  GNOME: true,
  KDE: true,
  XFCE: true,
  X_Red_Hat_Base: true
}

function normalizeSource(value) {
  const text = String(value === undefined || value === null ? "" : value).trim()
  if (text === "categories")
    return "categories"
  return "xdgMenu"
}

function folderNode(id, label, icon, children) {
  return {
    kind: "folder",
    id: String(id || ""),
    label: String(label || ""),
    icon: String(icon || ""),
    children: Array.isArray(children) ? children : []
  }
}

function appNode(entryId, label, icon) {
  return {
    kind: "app",
    id: String(entryId || ""),
    entryId: String(entryId || ""),
    label: String(label || ""),
    icon: String(icon || ""),
    children: []
  }
}

function separatorNode(id) {
  return {
    kind: "separator",
    id: String(id || "sep"),
    label: "",
    icon: "",
    children: []
  }
}

function actionNode(action, label, icon) {
  return {
    kind: "action",
    id: String(action || ""),
    action: String(action || ""),
    label: String(label || ""),
    icon: String(icon || ""),
    children: []
  }
}

function classicShellItems() {
  return [
    separatorNode("sep-shell"),
    actionNode("documents", "Documents", "folder-documents"),
    actionNode("settings", "Settings", "preferences-system"),
    actionNode("search", "Search...", "system-search"),
    actionNode("help", "Help and Support", "help-browser"),
    actionNode("run", "Run...", "system-run")
  ]
}

function classicSessionItems() {
  return [
    separatorNode("sep-session"),
    actionNode("logoff", "Log Off...", "system-log-out"),
    actionNode("shutdown", "Shut Down...", "system-shutdown")
  ]
}

function isFolder(node) {
  return node && node.kind === "folder"
}

function isApp(node) {
  return node && node.kind === "app"
}

function primaryCategory(categories) {
  const list = Array.isArray(categories) ? categories : []
  for (let i = 0; i < CATEGORY_ORDER.length; ++i) {
    const key = CATEGORY_ORDER[i]
    if (list.indexOf(key) >= 0)
      return key
  }
  for (let j = 0; j < list.length; ++j) {
    const cat = String(list[j] || "")
    if (cat && !SKIP_CATEGORIES[cat] && !cat.startsWith("X-"))
      return cat
  }
  return ""
}

function entryToAppNode(entry) {
  if (!entry)
    return null
  const id = String(entry.id || "")
  const name = String(entry.name || "").trim()
  if (!id || !name)
    return null
  return appNode(id, name, entry.icon || "")
}

function sortNodes(nodes) {
  const list = Array.isArray(nodes) ? nodes.slice() : []
  list.sort(function(a, b) {
    const la = String(a && a.label || "").toLocaleLowerCase()
    const lb = String(b && b.label || "").toLocaleLowerCase()
    if (la < lb)
      return -1
    if (la > lb)
      return 1
    return 0
  })
  return list
}

function buildCategoryTree(entries) {
  const buckets = {}
  const list = Array.isArray(entries) ? entries : []
  for (let i = 0; i < list.length; ++i) {
    const entry = list[i]
    if (!entry || entry.noDisplay)
      continue
    const name = String(entry.name || "").trim()
    if (!name)
      continue
    const key = primaryCategory(entry.categories) || "Other"
    if (!buckets[key])
      buckets[key] = []
    const node = entryToAppNode(entry)
    if (node)
      buckets[key].push(node)
  }

  const children = []
  const seen = {}
  for (let o = 0; o < CATEGORY_ORDER.length; ++o) {
    const key = CATEGORY_ORDER[o]
    if (!buckets[key] || !buckets[key].length)
      continue
    seen[key] = true
    children.push(folderNode(
      "cat:" + key,
      CATEGORY_LABELS[key] || key,
      "",
      sortNodes(buckets[key])
    ))
  }

  const leftovers = Object.keys(buckets).sort()
  for (let k = 0; k < leftovers.length; ++k) {
    const key = leftovers[k]
    if (seen[key] || !buckets[key].length)
      continue
    const label = key === "Other" ? "Other" : (CATEGORY_LABELS[key] || key)
    children.push(folderNode("cat:" + key, label, "", sortNodes(buckets[key])))
  }

  return folderNode("programs", "Programs", "", children)
}

function pruneEmptyFolders(node) {
  if (!node || node.kind !== "folder")
    return node
  const kids = []
  const raw = Array.isArray(node.children) ? node.children : []
  for (let i = 0; i < raw.length; ++i) {
    const child = raw[i]
    if (!child)
      continue
    if (child.kind === "folder") {
      const pruned = pruneEmptyFolders(child)
      if (pruned && pruned.children && pruned.children.length)
        kids.push(pruned)
    } else {
      kids.push(child)
    }
  }
  return folderNode(node.id, node.label, node.icon, kids)
}
