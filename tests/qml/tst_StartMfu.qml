import QtQuick
import QtTest
import "../../QuickXP/StartMfu.js" as StartMfu

TestCase {
  name: "StartMfu"

  function test_bump_and_rank() {
    let raw = "{}"
    raw = StartMfu.bumpScore(raw, "a.desktop", 7, 1000000)
    raw = StartMfu.bumpScore(raw, "a.desktop", 7, 1000000)
    raw = StartMfu.bumpScore(raw, "b.desktop", 7, 1000000)
    const ranked = StartMfu.rankedIds(raw, "[]", [], 10, 1000000)
    compare(ranked[0], "a.desktop")
    verify(ranked.indexOf("b.desktop") >= 0)
  }

  function test_excludes_pins_and_removed() {
    let raw = StartMfu.bumpScore("{}", "a.desktop", 7, 1)
    raw = StartMfu.bumpScore(raw, "b.desktop", 7, 1)
    raw = StartMfu.bumpScore(raw, "c.desktop", 7, 1)
    const excluded = StartMfu.exclude("[]", "b.desktop")
    const ranked = StartMfu.rankedIds(raw, excluded, ["a.desktop"], 10, 1)
    compare(ranked.indexOf("a.desktop"), -1)
    compare(ranked.indexOf("b.desktop"), -1)
    compare(ranked[0], "c.desktop")
  }

  function test_remove_and_clear() {
    let raw = StartMfu.bumpScore("{}", "a.desktop", 7, 1)
    raw = StartMfu.removeFromList(raw, "a.desktop")
    compare(StartMfu.rankedIds(raw, "[]", [], 5, 1).length, 0)
    compare(StartMfu.clearList(), "{}")
  }
}
