import QtQuick
import QtTest
import "../../QuickXP/QuickLaunchModel.js" as QuickLaunchModel
import "../../QuickXP/ToolbarModel.js" as ToolbarModel

TestCase {
  name: "QuickLaunchModel"

  function test_default_includes_show_desktop() {
    const ids = QuickLaunchModel.defaultIds([])
    compare(ids[0], QuickLaunchModel.showDesktopId())
  }

  function test_parse_and_remove() {
    const raw = QuickLaunchModel.idsJson([
      QuickLaunchModel.showDesktopId(),
      "firefox.desktop",
      "kate.desktop"
    ])
    const ids = QuickLaunchModel.parseIds(raw)
    compare(ids.length, 3)
    const next = QuickLaunchModel.parseIds(QuickLaunchModel.remove(raw, "firefox.desktop"))
    compare(next.length, 2)
    compare(next[1], "kate.desktop")
    // Cannot remove show-desktop.
    compare(QuickLaunchModel.parseIds(QuickLaunchModel.remove(raw, QuickLaunchModel.showDesktopId())).length, 3)
  }

  function test_move_keeps_show_desktop_first() {
    const raw = QuickLaunchModel.idsJson([
      QuickLaunchModel.showDesktopId(),
      "a.desktop",
      "b.desktop"
    ])
    const moved = QuickLaunchModel.parseIds(QuickLaunchModel.move(raw, 2, 1))
    compare(moved[0], QuickLaunchModel.showDesktopId())
    compare(moved[1], "b.desktop")
    compare(moved[2], "a.desktop")
  }

  function test_visible_slice_overflow() {
    const ids = ["a", "b", "c", "d", "e"]
    const slice = QuickLaunchModel.visibleSlice(ids, 60, 16)
    // slot = 24; with chevron need room → fewer visible
    verify(slice.visible.length < ids.length)
    verify(slice.overflow.length > 0)
    compare(slice.visible.length + slice.overflow.length, ids.length)
  }

  function test_icon_size_for_height() {
    compare(QuickLaunchModel.iconSizeForHeight(30), 16)
    compare(QuickLaunchModel.iconSizeForHeight(40), 24)
    compare(QuickLaunchModel.iconSizeForHeight(56), 32)
  }

  function test_toolbar_upsert_and_width() {
    let raw = ToolbarModel.toolbarsJson([])
    raw = ToolbarModel.upsertFolder(raw, "Desktop", "/home/u/Desktop", 100)
    let list = ToolbarModel.parseToolbars(raw)
    compare(list.length, 1)
    compare(list[0].id, "Desktop")
    raw = ToolbarModel.setWidth(raw, "Desktop", 160)
    list = ToolbarModel.parseToolbars(raw)
    compare(list[0].width, 160)
  }

  function test_toolbar_toggle_folder() {
    let raw = ToolbarModel.toolbarsJson([])
    raw = ToolbarModel.toggleFolder(raw, "Links", "/home/u/Links", 120)
    compare(ToolbarModel.isVisible(raw, "Links"), true)
    raw = ToolbarModel.toggleFolder(raw, "Links", "/home/u/Links", 120)
    compare(ToolbarModel.isVisible(raw, "Links"), false)
  }
}
