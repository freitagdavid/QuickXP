import QtQuick
import QtTest
import "../../QuickXP/start/StartMenuLayout.js" as StartMenuLayout

TestCase {
  name: "StartMenuLayout"

  function test_useClassic() {
    compare(StartMenuLayout.useClassic("classic"), true)
    compare(StartMenuLayout.useClassic("Classic"), true)
    compare(StartMenuLayout.useClassic(" xp "), false)
    compare(StartMenuLayout.useClassic("vista"), false)
    compare(StartMenuLayout.useClassic("win7"), false)
    compare(StartMenuLayout.useClassic(""), false)
    compare(StartMenuLayout.useClassic(undefined), false)
    compare(StartMenuLayout.useClassic(null), false)
  }

  function test_useXpDualColumn() {
    compare(StartMenuLayout.useXpDualColumn("classic"), false)
    compare(StartMenuLayout.useXpDualColumn("xp"), true)
    compare(StartMenuLayout.useXpDualColumn("vista"), true)
    compare(StartMenuLayout.useXpDualColumn("win7"), true)
  }

  function test_useStartSearch() {
    compare(StartMenuLayout.useStartSearch(true), true)
    compare(StartMenuLayout.useStartSearch(false), false)
    compare(StartMenuLayout.useStartSearch(undefined), false)
    compare(StartMenuLayout.useStartSearch(1), false)
  }
}
