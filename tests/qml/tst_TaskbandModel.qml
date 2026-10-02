import QtQuick
import QtTest
import "../../QuickXP/TaskbandModel.js" as TaskbandModel

TestCase {
  name: "TaskbandModel"

  function win(appId, title, extras) {
    const row = {
      appId: appId || "",
      title: title || "",
      activated: false,
      minimized: false,
      kwin: true,
      windowId: title || appId || Math.random().toString()
    }
    if (extras) {
      for (const key in extras)
        row[key] = extras[key]
    }
    return row
  }

  function test_groupKey_appId() {
    compare(TaskbandModel.groupKey(win("org.kde.dolphin", "Home")), "a:org.kde.dolphin")
  }

  function test_groupKey_empty_app_unique() {
    const a = win("", "One", { windowId: "1" })
    const b = win("", "Two", { windowId: "2" })
    verify(TaskbandModel.groupKey(a) !== TaskbandModel.groupKey(b))
  }

  function test_appLabel_prefers_appName() {
    compare(TaskbandModel.appLabel(win("x.y.Z", "Title", { appName: "Zed" })), "Zed")
  }

  function test_needsPaging() {
    // 3 * 48 + 2 * 3 = 150; width 149 → page, 150 → fit
    compare(TaskbandModel.needsPaging(3, 149, 48, 3), true)
    compare(TaskbandModel.needsPaging(3, 150, 48, 3), false)
    compare(TaskbandModel.needsPaging(0, 100, 48, 3), false)
  }

  function test_flat_when_grouping_off() {
    const windows = [
      win("app.a", "A1"),
      win("app.a", "A2"),
      win("app.b", "B1")
    ]
    const entries = TaskbandModel.buildEntries(windows, {
      groupButtons: false,
      iconsOnly: false,
      bandWidth: 40,
      minButtonWidth: 48,
      spacing: 3
    })
    compare(entries.length, 3)
    compare(entries[0].count, 1)
    compare(entries[0].kind, "window")
  }

  function test_always_combine_iconsOnly() {
    const windows = [
      win("app.a", "A1"),
      win("app.a", "A2"),
      win("app.b", "B1")
    ]
    const entries = TaskbandModel.buildEntries(windows, {
      groupButtons: true,
      iconsOnly: true,
      bandWidth: 1000,
      minButtonWidth: 48,
      spacing: 3
    })
    compare(entries.length, 2)
    compare(entries[0].count, 2)
    compare(entries[0].kind, "group")
    compare(entries[0].title, "a")
    compare(entries[1].count, 1)
  }

  function test_crowding_only_when_full() {
    const windows = [
      win("app.a", "A1"),
      win("app.a", "A2"),
      win("app.b", "B1")
    ]
    const roomy = TaskbandModel.buildEntries(windows, {
      groupButtons: true,
      iconsOnly: false,
      bandWidth: 1000,
      minButtonWidth: 48,
      spacing: 3
    })
    compare(roomy.length, 3)

    const tight = TaskbandModel.buildEntries(windows, {
      groupButtons: true,
      iconsOnly: false,
      bandWidth: 40,
      minButtonWidth: 48,
      spacing: 3
    })
    compare(tight.length, 2)
    compare(tight[0].count, 2)
  }

  function test_representative_prefers_active() {
    const windows = [
      win("app.a", "A1", { activated: false }),
      win("app.a", "A2", { activated: true, minimized: false })
    ]
    const entries = TaskbandModel.buildEntries(windows, {
      groupButtons: true,
      iconsOnly: true,
      bandWidth: 100,
      minButtonWidth: 48,
      spacing: 3
    })
    compare(entries[0].representative.title, "A2")
  }

  function test_entryKey_stable_across_title_change() {
    const a = TaskbandModel.entryFromWindows([
      win("app.a", "Old", { windowId: "1" })
    ])
    const b = TaskbandModel.entryFromWindows([
      win("app.a", "New", { windowId: "1" })
    ])
    compare(TaskbandModel.entryKey(a), TaskbandModel.entryKey(b))
    compare(a.key, "k:1")
  }

  function test_entryKey_flat_same_app_unique() {
    const a = TaskbandModel.entryFromWindows([win("app.a", "A1", { windowId: "1" })])
    const b = TaskbandModel.entryFromWindows([win("app.a", "A2", { windowId: "2" })])
    verify(TaskbandModel.entryKey(a) !== TaskbandModel.entryKey(b))
  }

  function test_entryKey_group_by_app() {
    const g = TaskbandModel.entryFromWindows([
      win("app.a", "A1", { windowId: "1" }),
      win("app.a", "A2", { windowId: "2" })
    ])
    compare(g.kind, "group")
    compare(TaskbandModel.entryKey(g), "a:app.a")
  }

  function test_diffEntries_title_only_is_update() {
    const prev = TaskbandModel.stampEntries([
      TaskbandModel.entryFromWindows([win("app.a", "Old", { windowId: "1" })])
    ])
    const next = TaskbandModel.stampEntries([
      TaskbandModel.entryFromWindows([win("app.a", "New", { windowId: "1", activated: true })])
    ])
    const diff = TaskbandModel.diffEntries(prev, next)
    compare(diff.removes.length, 0)
    compare(diff.inserts.length, 0)
    compare(diff.updates.length, 1)
    compare(diff.updates[0].entry.title, "New")
    verify(diff.sameLength)
  }

  function test_diffEntries_insert_remove() {
    const prev = TaskbandModel.stampEntries([
      TaskbandModel.entryFromWindows([win("app.a", "A", { windowId: "1" })])
    ])
    const next = TaskbandModel.stampEntries([
      TaskbandModel.entryFromWindows([win("app.b", "B", { windowId: "2" })])
    ])
    const diff = TaskbandModel.diffEntries(prev, next)
    compare(diff.removes.length, 1)
    compare(diff.inserts.length, 1)
    compare(diff.updates.length, 0)
  }

  function test_pageSlice() {
    const all = TaskbandModel.stampEntries([
      TaskbandModel.entryFromWindows([win("a", "1", { windowId: "1" })]),
      TaskbandModel.entryFromWindows([win("b", "2", { windowId: "2" })]),
      TaskbandModel.entryFromWindows([win("c", "3", { windowId: "3" })])
    ])
    compare(TaskbandModel.pageSlice(all, 0, 2, false).length, 3)
    const page0 = TaskbandModel.pageSlice(all, 0, 2, true)
    compare(page0.length, 2)
    compare(page0[0].title, "1")
    const page1 = TaskbandModel.pageSlice(all, 1, 2, true)
    compare(page1.length, 1)
    compare(page1[0].title, "3")
  }
}
