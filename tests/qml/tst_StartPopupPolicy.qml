import QtQuick
import QtTest
import "../../QuickXP/start/StartPopupPolicy.js" as StartPopupPolicy

TestCase {
  name: "StartPopupPolicy"

  function test_keepOpenEnabled() {
    compare(StartPopupPolicy.keepOpenEnabled(true), true)
    compare(StartPopupPolicy.keepOpenEnabled(false), false)
    compare(StartPopupPolicy.keepOpenEnabled(undefined), false)
    compare(StartPopupPolicy.keepOpenEnabled(null), false)
  }

  function test_allowAutoClose() {
    compare(StartPopupPolicy.allowAutoClose(false), true)
    compare(StartPopupPolicy.allowAutoClose(true), false)
  }

  function test_allowClose() {
    compare(StartPopupPolicy.allowClose(false, false), true)
    compare(StartPopupPolicy.allowClose(false, true), true)
    compare(StartPopupPolicy.allowClose(true, false), false)
    compare(StartPopupPolicy.allowClose(true, undefined), false)
    compare(StartPopupPolicy.allowClose(true, true), true)
  }

  function test_wantGrabFocus() {
    compare(StartPopupPolicy.wantGrabFocus(false), true)
    compare(StartPopupPolicy.wantGrabFocus(true), false)
    compare(StartPopupPolicy.wantGrabFocus(false, false), true)
    compare(StartPopupPolicy.wantGrabFocus(false, true), false)
    compare(StartPopupPolicy.wantGrabFocus(true, true), false)
  }

  function test_allowLeaveClose() {
    compare(StartPopupPolicy.allowLeaveClose(false, true, false), false)
    compare(StartPopupPolicy.allowLeaveClose(true, false, false), false)
    compare(StartPopupPolicy.allowLeaveClose(true, true, true), false)
    compare(StartPopupPolicy.allowLeaveClose(true, true, false), true)
  }

  function test_shouldReclaim() {
    compare(StartPopupPolicy.shouldReclaim(true, true, false), true)
    compare(StartPopupPolicy.shouldReclaim(true, true, true), false)
    compare(StartPopupPolicy.shouldReclaim(true, false, false), false)
    compare(StartPopupPolicy.shouldReclaim(false, true, false), false)
  }
}
