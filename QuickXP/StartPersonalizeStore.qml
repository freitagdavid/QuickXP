pragma Singleton

import QtQuick
import Quickshell
import qs.QuickXP
import "StartPersonalize.js" as StartPersonalize

Singleton {
  id: root

  property var expandedFolders: ({})
  property int _revision: 0

  readonly property bool enabled: Config.options.startPersonalizedMenus

  function bump(entryId) {
    if (!entryId)
      return
    Config.options.startAppUsage = StartPersonalize.bumpUsage(Config.options.startAppUsage, entryId)
    root._revision++
  }

  function expandFolder(folderId) {
    const next = Object.assign({}, root.expandedFolders)
    next[String(folderId || "")] = true
    root.expandedFolders = next
    root._revision++
  }

  function resetExpanded() {
    root.expandedFolders = {}
    root._revision++
  }

  function decoratePrograms(node) {
    const _ = root._revision
    if (!root.enabled || !node)
      return node
    const expanded = !!root.expandedFolders[String(node.id || "")]
    // Recurse: personalizeFolder already recurses into child folders with same expanded flag per call.
    // Expand is per-folder id: re-walk with per-node expanded state.
    return personalizeWalk(node)
  }

  function personalizeWalk(node) {
    if (!node || node.kind !== "folder")
      return node
    const expanded = !!root.expandedFolders[String(node.id || "")]
    const kids = Array.isArray(node.children) ? node.children : []
    const walked = []
    for (let i = 0; i < kids.length; ++i) {
      const child = kids[i]
      if (child && child.kind === "folder")
        walked.push(personalizeWalk(child))
      else
        walked.push(child)
    }
    const folded = {
      kind: node.kind,
      id: node.id,
      label: node.label,
      icon: node.icon || "",
      mnemonic: node.mnemonic || "",
      children: walked,
      entryId: node.entryId || "",
      action: node.action || "",
      uri: node.uri || "",
      isNew: !!node.isNew,
      hasNew: !!node.hasNew
    }
    return StartPersonalize.personalizeFolder(
      folded,
      Config.options.startAppUsage,
      Config.options.startPersonalizedThreshold,
      expanded
    )
  }

  Connections {
    target: Config.options
    function onStartPersonalizedMenusChanged() {
      root.resetExpanded()
    }
  }
}
