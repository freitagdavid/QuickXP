import QtQuick
import QtTest
import "../../QuickXP/StartPin.js" as StartPin

TestCase {
  name: "StartPin"

  function test_parse_and_pin_unpin() {
    compare(StartPin.parsePins("[]").length, 0)
    let raw = StartPin.pin("[]", "firefox.desktop")
    compare(StartPin.parsePins(raw).length, 1)
    raw = StartPin.pin(raw, "firefox.desktop")
    compare(StartPin.parsePins(raw).length, 1)
    raw = StartPin.pin(raw, "thunderbird.desktop")
    compare(StartPin.parsePins(raw)[1], "thunderbird.desktop")
    raw = StartPin.unpin(raw, "firefox.desktop")
    compare(StartPin.parsePins(raw)[0], "thunderbird.desktop")
    verify(StartPin.isPinned(raw, "thunderbird.desktop"))
    verify(!StartPin.isPinned(raw, "firefox.desktop"))
  }

  function test_move() {
    const raw = StartPin.pinsJson(["a", "b", "c"])
    const moved = StartPin.move(raw, 0, 2)
    const ids = StartPin.parsePins(moved)
    compare(ids[0], "b")
    compare(ids[1], "c")
    compare(ids[2], "a")
  }

  function test_defaultPinIds() {
    const apps = [
      { id: "mail.desktop", categories: ["Email"] },
      { id: "www.desktop", categories: ["WebBrowser"] },
      { id: "other.desktop", categories: ["Utility"] }
    ]
    const ids = StartPin.defaultPinIds(apps)
    compare(ids[0], "www.desktop")
    compare(ids[1], "mail.desktop")
  }
}
