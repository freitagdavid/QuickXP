import QtQuick
import QtTest
import "../../QuickXP/StartMenuModel.js" as StartMenuModel

TestCase {
  name: "StartMenuModel"

  function test_normalizeSource() {
    compare(StartMenuModel.normalizeSource(""), "xdgMenu")
    compare(StartMenuModel.normalizeSource("xdgMenu"), "xdgMenu")
    compare(StartMenuModel.normalizeSource("categories"), "categories")
    compare(StartMenuModel.normalizeSource("bogus"), "xdgMenu")
  }

  function test_primaryCategory() {
    compare(StartMenuModel.primaryCategory(["Network", "WebBrowser"]), "Network")
    compare(StartMenuModel.primaryCategory(["Utility", "System"]), "Utility")
    compare(StartMenuModel.primaryCategory([]), "")
  }

  function test_classicShellItems() {
    const recent = [{ kind: "action", action: "open-uri", label: "notes.txt", uri: "file:///tmp/notes.txt" }]
    const favs = [{ kind: "action", action: "open-uri", label: "Music", uri: "file:///home/u/Music" }]
    const rows = StartMenuModel.classicShellItems(recent, favs)
    verify(rows.length >= 6)
    compare(rows[0].kind, "folder")
    compare(rows[0].id, "favorites")
    compare(rows[1].kind, "separator")
    const docs = rows.filter(function(r) { return r.id === "documents" })[0]
    verify(docs.children.length >= 3)
    const folders = rows.filter(function(r) { return r.kind === "folder" }).map(function(r) { return r.id })
    verify(folders.indexOf("documents") >= 0)
    verify(folders.indexOf("settings") >= 0)
    verify(folders.indexOf("search") >= 0)
  }

  function test_keyboardHelpers() {
    const rows = [
      { kind: "separator" },
      { kind: "folder", label: "Programs", mnemonic: "p" },
      { kind: "action", label: "Run...", mnemonic: "r" },
      { kind: "separator" },
      { kind: "action", label: "Turn Off Computer...", mnemonic: "u" }
    ]
    compare(StartMenuModel.nextSelectableIndex(rows, -1, 1), 1)
    compare(StartMenuModel.nextSelectableIndex(rows, 1, 1), 2)
    compare(StartMenuModel.nextSelectableIndex(rows, 2, 1), 4)
    compare(StartMenuModel.nextSelectableIndex(rows, 4, 1), 1)
    compare(StartMenuModel.nextSelectableIndex(rows, 1, -1), 4)
    compare(StartMenuModel.mnemonicIndex(rows, "r"), 2)
    compare(StartMenuModel.mnemonicIndex(rows, "u"), 4)
    compare(StartMenuModel.mnemonicIndex(rows, "z"), -1)
  }

  function test_classicSessionItems() {
    const rows = StartMenuModel.classicSessionItems("Administrator")
    compare(rows[0].kind, "separator")
    const logoff = rows.filter(function(r) { return r.action === "logoff" })[0]
    verify(logoff.label.indexOf("Administrator") >= 0)
    verify(logoff.label.indexOf("Log Off") >= 0)
    const shutdown = rows.filter(function(r) { return r.action === "shutdown" })[0]
    compare(shutdown.label, "Turn Off Computer...")
  }

  function test_buildCategoryTree() {
    const entries = [
      { id: "a", name: "Alpha", icon: "a", categories: ["Network"], noDisplay: false },
      { id: "b", name: "Beta", icon: "b", categories: ["Utility"], noDisplay: false },
      { id: "c", name: "Hidden", icon: "c", categories: ["Utility"], noDisplay: true }
    ]
    const tree = StartMenuModel.buildCategoryTree(entries)
    compare(tree.label, "Programs")
    verify(tree.children.length >= 2)
    let labels = []
    for (let i = 0; i < tree.children.length; ++i) {
      const folder = tree.children[i]
      for (let j = 0; j < folder.children.length; ++j)
        labels.push(folder.children[j].label)
    }
    verify(labels.indexOf("Alpha") >= 0)
    verify(labels.indexOf("Beta") >= 0)
    verify(labels.indexOf("Hidden") < 0)
  }
}
