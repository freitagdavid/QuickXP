.pragma library

function keepOpenEnabled(flag) {
  return flag === true
}

function allowAutoClose(keepOpen) {
  return !keepOpenEnabled(keepOpen)
}

function wantGrabFocus(keepOpen, openedByHotkey) {
  // Debug latch: no grab.
  if (keepOpenEnabled(keepOpen))
    return false
  // Meta/hotkey: Qt::Popup grab fails (panel never received input) and/or the
  // key-up is treated as an outside click. Use Qt::ToolTip instead.
  if (openedByHotkey === true)
    return false
  return true
}

// Pointer-leave auto-close only after the cursor has actually entered Start chrome.
// Otherwise a Meta open is dismissed ~320ms later while the pointer is still on the desktop.
function allowLeaveClose(everHovered, armed, suppressDismiss) {
  if (everHovered !== true)
    return false
  if (armed !== true)
    return false
  if (suppressDismiss === true)
    return false
  return true
}

function shouldReclaim(keepOpen, wantOpen, visible) {
  return keepOpenEnabled(keepOpen) && wantOpen === true && visible !== true
}

function allowClose(keepOpen, force) {
  if (keepOpenEnabled(keepOpen) && force !== true)
    return false
  return true
}
