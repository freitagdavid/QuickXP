.pragma library

// Pure helpers for tray volume icon + sink listing (Epic C).

function clampVolume(v) {
  var n = Number(v)
  if (isNaN(n))
    return 0
  if (n < 0)
    return 0
  if (n > 1)
    return 1
  return n
}

function adjustVolume(current, deltaSteps) {
  var step = 0.05
  var steps = Number(deltaSteps) || 0
  return clampVolume(clampVolume(current) + steps * step)
}

function volumeIconName(muted, volume) {
  if (muted)
    return "audio-volume-muted"
  var v = clampVolume(volume)
  if (v <= 0.01)
    return "audio-volume-muted"
  if (v < 0.34)
    return "audio-volume-low"
  if (v < 0.67)
    return "audio-volume-medium"
  return "audio-volume-high"
}

function volumePercent(volume) {
  return Math.round(clampVolume(volume) * 100)
}

function nodeLabel(node) {
  if (!node)
    return ""
  var nick = node.nickname
  if (nick !== undefined && nick !== null && String(nick).trim() !== "")
    return String(nick)
  var desc = node.description
  if (desc !== undefined && desc !== null && String(desc).trim() !== "")
    return String(desc)
  return String(node.name || "")
}

function streamLabel(node) {
  if (!node)
    return ""
  var props = node.properties || ({})
  var app = props["application.name"]
  if (app === undefined || app === null || String(app).trim() === "")
    app = nodeLabel(node)
  var media = props["media.name"]
  if (media !== undefined && media !== null && String(media).trim() !== "")
    return String(app) + " — " + String(media)
  return String(app)
}

function streamIconName(node) {
  if (!node)
    return "audio-volume-high"
  var props = node.properties || ({})
  var icon = props["application.icon-name"]
  if (icon !== undefined && icon !== null && String(icon).trim() !== "")
    return String(icon)
  return "audio-volume-high"
}

function isAudioSinkNode(node) {
  if (!node)
    return false
  if (node.isStream)
    return false
  return !!node.isSink
}

function listSinkNodes(nodesModel) {
  var out = []
  if (!nodesModel)
    return out
  var values = nodesModel.values !== undefined ? nodesModel.values : nodesModel
  if (!values || values.length === undefined) {
    // UntypedObjectModel may only support indexing via .values
    try {
      values = Array.from(nodesModel)
    } catch (e) {
      return out
    }
  }
  for (var i = 0; i < values.length; ++i) {
    var n = values[i]
    if (isAudioSinkNode(n))
      out.push(n)
  }
  return out
}

function pactlMoveSinkInputCommand(sinkInputIndex, sinkName) {
  var idx = String(sinkInputIndex || "").trim()
  var sink = String(sinkName || "").trim()
  if (!idx || !sink)
    return []
  return ["pactl", "move-sink-input", idx, sink]
}

function pulseSinkInputIndex(node) {
  if (!node || !node.properties)
    return ""
  var props = node.properties
  var keys = ["pulse.cookie", "object.serial", "pulse.id"]
  for (var i = 0; i < keys.length; ++i) {
    var v = props[keys[i]]
    if (v !== undefined && v !== null && String(v).trim() !== "")
      return String(v).trim()
  }
  return ""
}
