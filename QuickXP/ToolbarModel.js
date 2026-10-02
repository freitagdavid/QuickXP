.pragma library

// Taskbar folder toolbars (Desktop / Links / custom).

function parseToolbars(raw) {
  try {
    var value = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(value))
      return []
    var out = []
    for (var i = 0; i < value.length; ++i) {
      var row = value[i]
      if (!row || typeof row !== "object")
        continue
      var id = String(row.id || "").trim()
      if (!id)
        continue
      out.push({
        id: id,
        kind: String(row.kind || "folder"),
        path: String(row.path || ""),
        showText: row.showText === true,
        showTitle: row.showTitle !== false,
        width: Math.max(48, Number(row.width) || 120),
        visible: row.visible !== false
      })
    }
    return out
  } catch (error) {
    return []
  }
}

function toolbarsJson(list) {
  return JSON.stringify(Array.isArray(list) ? list : [])
}

function defaultToolbars() {
  return []
}

function findToolbar(raw, toolbarId) {
  var list = parseToolbars(raw)
  var id = String(toolbarId || "")
  for (var i = 0; i < list.length; ++i) {
    if (list[i].id === id)
      return list[i]
  }
  return null
}

function isVisible(raw, toolbarId) {
  var row = findToolbar(raw, toolbarId)
  return !!(row && row.visible)
}

function setVisible(raw, toolbarId, visible) {
  var list = parseToolbars(raw)
  var id = String(toolbarId || "")
  for (var i = 0; i < list.length; ++i) {
    if (list[i].id === id)
      list[i].visible = !!visible
  }
  return toolbarsJson(list)
}

function toggleFolder(raw, toolbarId, path, width) {
  if (isVisible(raw, toolbarId))
    return setVisible(raw, toolbarId, false)
  return upsertFolder(raw, toolbarId, path, width)
}

function upsertFolder(raw, toolbarId, path, width) {
  var list = parseToolbars(raw)
  var id = String(toolbarId || path || "folder")
  var found = false
  for (var i = 0; i < list.length; ++i) {
    if (list[i].id === id) {
      list[i].path = String(path || "")
      list[i].visible = true
      if (width)
        list[i].width = Math.max(48, Number(width) || list[i].width)
      found = true
      break
    }
  }
  if (!found) {
    list.push({
      id: id,
      kind: "folder",
      path: String(path || ""),
      showText: false,
      showTitle: true,
      width: Math.max(48, Number(width) || 120),
      visible: true
    })
  }
  return toolbarsJson(list)
}

function removeToolbar(raw, toolbarId) {
  var list = parseToolbars(raw)
  var id = String(toolbarId || "")
  var next = []
  for (var i = 0; i < list.length; ++i) {
    if (list[i].id !== id)
      next.push(list[i])
  }
  return toolbarsJson(next)
}

function setWidth(raw, toolbarId, width) {
  var list = parseToolbars(raw)
  var id = String(toolbarId || "")
  var w = Math.max(48, Number(width) || 120)
  for (var i = 0; i < list.length; ++i) {
    if (list[i].id === id)
      list[i].width = w
  }
  return toolbarsJson(list)
}
