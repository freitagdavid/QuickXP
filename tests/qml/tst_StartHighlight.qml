import QtQuick
import QtTest
import "../../QuickXP/StartHighlight.js" as StartHighlight

TestCase {
  name: "StartHighlight"

  function test_seed_first_run() {
    const result = StartHighlight.reconcile("[]", ["a", "b"], false)
    compare(result.newIds.length, 0)
    verify(result.seeded)
    verify(result.seenJson.indexOf("a") >= 0)
  }

  function test_detect_new() {
    const seen = StartHighlight.toIdListJson(["a", "b"])
    const result = StartHighlight.reconcile(seen, ["a", "b", "c"], true)
    compare(result.newIds.length, 1)
    compare(result.newIds[0], "c")
  }

  function test_markSeen() {
    const next = StartHighlight.markSeen("[]", "firefox")
    verify(next.indexOf("firefox") >= 0)
    compare(StartHighlight.markSeen(next, "firefox"), next)
  }

  function test_markNodeTree() {
    const tree = {
      kind: "folder",
      id: "p",
      label: "Programs",
      children: [
        { kind: "app", id: "old", entryId: "old", label: "Old", children: [] },
        { kind: "app", id: "new", entryId: "new", label: "New", children: [] }
      ]
    }
    const marked = StartHighlight.markNodeTree(tree, { new: true })
    verify(marked.hasNew)
    compare(marked.children[0].isNew, false)
    compare(marked.children[1].isNew, true)
  }
}
