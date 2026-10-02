import QtQuick
import QtTest
import "../../QuickXP/start/StartSubmenuChrome.js" as StartSubmenuChrome

TestCase {
  name: "StartSubmenuChrome"

  function test_isXp() {
    compare(StartSubmenuChrome.isXp("xp"), true)
    compare(StartSubmenuChrome.isXp("XP"), true)
    compare(StartSubmenuChrome.isXp("startgroup"), true)
    compare(StartSubmenuChrome.isXp("luna"), true)
    compare(StartSubmenuChrome.isXp("classic"), false)
    compare(StartSubmenuChrome.isXp(""), false)
    compare(StartSubmenuChrome.isXp(undefined), false)
    compare(StartSubmenuChrome.isXp(null), false)
  }

  function test_isClassic() {
    compare(StartSubmenuChrome.isClassic("classic"), true)
    compare(StartSubmenuChrome.isClassic(""), true)
    compare(StartSubmenuChrome.isClassic("xp"), false)
  }

  function test_rowHeight() {
    compare(StartSubmenuChrome.rowHeight("xp"), 22)
    compare(StartSubmenuChrome.rowHeight("classic"), 32)
    compare(StartSubmenuChrome.rowHeight(""), 32)
  }

  function test_iconSize() {
    compare(StartSubmenuChrome.iconSize("xp"), 16)
    compare(StartSubmenuChrome.iconSize("classic"), 32)
  }
}
