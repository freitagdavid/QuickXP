.pragma library

function keepOpenEnabled(flag) {
  return flag === true
}

function allowAutoClose(keepOpen) {
  return !keepOpenEnabled(keepOpen)
}

function wantGrabFocus(keepOpen) {
  return !keepOpenEnabled(keepOpen)
}

function shouldReclaim(keepOpen, wantOpen, visible) {
  return keepOpenEnabled(keepOpen) && wantOpen === true && visible !== true
}

function allowClose(keepOpen, force) {
  if (keepOpenEnabled(keepOpen) && force !== true)
    return false
  return true
}
