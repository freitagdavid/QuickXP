import QtQuick
import qs.QuickXP

// Full-window click catcher: PopupWindow grab often misses clicks on the parent
// FloatingWindow/PopupWindow, so dismiss open dropdowns from inside the host.
MouseArea {
  id: root

  anchors.fill: parent
  z: 100000
  enabled: DropdownGate.active !== null
  visible: enabled
  hoverEnabled: false
  acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
  // Steal the click so the same combo doesn't toggle back open underneath.
  onPressed: DropdownGate.dismiss()
}
