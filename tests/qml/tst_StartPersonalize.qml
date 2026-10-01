import QtQuick
import QtTest
import "../../QuickXP/StartPersonalize.js" as StartPersonalize

TestCase {
  name: "StartPersonalize"

  function test_bumpUsage() {
    const next = StartPersonalize.bumpUsage("{}", "a")
    const map = StartPersonalize.parseUsage(next)
    compare(map.a, 1)
  }

  function test_personalizeFolder_hides_low_usage() {
    const folder = {
      kind: "folder",
      id: "util",
      label: "Accessories",
      children: [
        { kind: "app", id: "rare", entryId: "rare", label: "Rare", children: [] },
        { kind: "app", id: "freq", entryId: "freq", label: "Freq", children: [] }
      ]
    }
    const usage = StartPersonalize.usageJson({ freq: 5 })
    const out = StartPersonalize.personalizeFolder(folder, usage, 1, false)
    const labels = out.children.map(function(c) { return c.label })
    verify(labels.indexOf("Freq") >= 0)
    verify(labels.indexOf("Rare") < 0)
    verify(labels.indexOf(">>") >= 0)
  }

  function test_personalizeFolder_expanded_shows_all() {
    const folder = {
      kind: "folder",
      id: "util",
      label: "Accessories",
      children: [
        { kind: "app", id: "rare", entryId: "rare", label: "Rare", children: [] }
      ]
    }
    const out = StartPersonalize.personalizeFolder(folder, "{}", 1, true)
    compare(out.children.length, 1)
    compare(out.children[0].label, "Rare")
  }
}
