import QtQuick
import QtTest
import "../../QuickXP/StartSearchModel.js" as StartSearchModel

TestCase {
  name: "StartSearchModel"

  function test_escClearsQuery() {
    compare(StartSearchModel.escClearsQuery(""), false)
    compare(StartSearchModel.escClearsQuery("  "), false)
    compare(StartSearchModel.escClearsQuery("term"), true)
  }

  function test_parseScoreMap() {
    const map = StartSearchModel.parseScoreMap('{"a.desktop":{"score":3.5,"last":1},"b.desktop":2}')
    compare(map["a.desktop"], 3.5)
    compare(map["b.desktop"], 2)
  }

  function test_buildResults_apps_rank_pins_and_prefix() {
    const apps = [
      { id: "zebra.desktop", name: "Zebra", icon: "z", noDisplay: false },
      { id: "apple.desktop", name: "Apple", icon: "a", noDisplay: false },
      { id: "apricot.desktop", name: "Apricot", icon: "ap", noDisplay: false }
    ]
    const rows = StartSearchModel.buildResults("ap", {
      apps: apps,
      pinIds: ["apricot.desktop"],
      mfuScores: { "apple.desktop": 5 },
      recentItems: [],
      settings: []
    })
    // header + two apps
    compare(rows[0].kind, "header")
    compare(rows[0].label, "Programs")
    compare(rows[1].entryId, "apricot.desktop")
    compare(rows[2].entryId, "apple.desktop")
  }

  function test_buildResults_documents_and_settings() {
    const rows = StartSearchModel.buildResults("theme", {
      apps: [],
      recentItems: [
        { id: "recent:0", label: "theme-notes.txt", uri: "file:///tmp/theme-notes.txt", icon: "text-x-generic" },
        { id: "recent:1", label: "other.pdf", uri: "file:///tmp/other.pdf", icon: "application-pdf" }
      ],
      settings: StartSearchModel.defaultSettingsIndex()
    })
    const kinds = rows.map(r => r.kind)
    verify(kinds.indexOf("header") >= 0)
    const labels = rows.filter(r => r.kind !== "header").map(r => r.label)
    verify(labels.indexOf("theme-notes.txt") >= 0)
    verify(labels.indexOf("Theme") >= 0)
    verify(labels.indexOf("Control Panel") >= 0)
  }

  function test_empty_query_returns_empty() {
    compare(StartSearchModel.buildResults("", {
      apps: [{ id: "a", name: "A", noDisplay: false }],
      recentItems: [{ label: "x", uri: "file:///x" }]
    }).length, 0)
  }

  function test_moveFocus_skips_headers() {
    const rows = [
      { kind: "header", label: "Programs" },
      { kind: "app", id: "a" },
      { kind: "header", label: "Settings" },
      { kind: "setting", id: "s" }
    ]
    compare(StartSearchModel.firstSelectableIndex(rows), 1)
    compare(StartSearchModel.moveFocus(rows, 1, 1), 3)
    compare(StartSearchModel.moveFocus(rows, 3, -1), 1)
    compare(StartSearchModel.moveFocus(rows, 1, -1), -1)
  }

  function test_filterApps_plain_records() {
    const apps = [
      { id: "firefox.desktop", name: "Firefox", genericName: "Web Browser", noDisplay: false },
      { id: "hidden.desktop", name: "Hidden", noDisplay: true }
    ]
    const hits = StartSearchModel.filterApps(apps, "fire")
    compare(hits.length, 1)
    compare(hits[0].entry.id, "firefox.desktop")
  }

  function test_buildAppSearchIndex_and_filterIndexed() {
    const apps = [
      { id: "firefox.desktop", name: "Firefox", genericName: "Web Browser", noDisplay: false },
      { id: "hidden.desktop", name: "Hidden", noDisplay: true }
    ]
    const index = StartSearchModel.buildAppSearchIndex(apps)
    compare(index.length, 1)
    compare(index[0].nameL, "firefox")
    const hits = StartSearchModel.filterAppsIndexed(index, "FIRE")
    compare(hits.length, 1)
    compare(hits[0].entry.id, "firefox.desktop")
  }

  function test_pinIdSet_boost() {
    const set = StartSearchModel.pinIdSet(["apricot.desktop", "  ", "other.desktop"])
    verify(set["apricot.desktop"])
    verify(set["other.desktop"])
    verify(!set[""])
    compare(StartSearchModel.pinBoost("apricot.desktop", set), 1000)
    compare(StartSearchModel.pinBoost("missing.desktop", set), 0)
    // Array fallback still works.
    compare(StartSearchModel.pinBoost("apricot.desktop", ["apricot.desktop"]), 1000)
  }

  function test_buildResults_uses_appIndex_and_pinSet() {
    const apps = [
      { id: "zebra.desktop", name: "Zebra", icon: "z", noDisplay: false },
      { id: "apple.desktop", name: "Apple", icon: "a", noDisplay: false },
      { id: "apricot.desktop", name: "Apricot", icon: "ap", noDisplay: false }
    ]
    const rows = StartSearchModel.buildResults("ap", {
      appIndex: StartSearchModel.buildAppSearchIndex(apps),
      pinSet: StartSearchModel.pinIdSet(["apricot.desktop"]),
      mfuScores: { "apple.desktop": 5 },
      recentItems: [],
      settings: []
    })
    compare(rows[1].entryId, "apricot.desktop")
    compare(rows[2].entryId, "apple.desktop")
  }
}
