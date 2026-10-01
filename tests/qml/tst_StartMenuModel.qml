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
    const rows = StartMenuModel.classicShellItems()
    verify(rows.length >= 5)
    compare(rows[0].kind, "separator")
    const actions = rows.filter(function(r) { return r.kind === "action" }).map(function(r) { return r.action })
    verify(actions.indexOf("documents") >= 0)
    verify(actions.indexOf("settings") >= 0)
    verify(actions.indexOf("search") >= 0)
    verify(actions.indexOf("help") >= 0)
    verify(actions.indexOf("run") >= 0)
  }

  function test_classicSessionItems() {
    const rows = StartMenuModel.classicSessionItems()
    compare(rows[0].kind, "separator")
    const actions = rows.filter(function(r) { return r.kind === "action" }).map(function(r) { return r.action })
    verify(actions.indexOf("logoff") >= 0)
    verify(actions.indexOf("shutdown") >= 0)
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
