pragma Singleton

import QtQuick
import Quickshell

// Ensures only one floating dropdown (combo / generation select) is open.
Singleton {
  id: root

  property var active: null
  readonly property bool open: active !== null && active !== undefined

  function claim(ctrl) {
    if (active !== null && active !== undefined && active !== ctrl) {
      try {
        active.closePopup()
      } catch (error) {
        // Control may have been destroyed.
      }
    }
    active = ctrl
  }

  function release(ctrl) {
    if (active === ctrl)
      active = null
  }

  function dismiss() {
    const ctrl = active
    active = null
    if (ctrl === null || ctrl === undefined)
      return
    try {
      ctrl.closePopup()
    } catch (error) {
      // Control may have been destroyed.
    }
  }
}
