import QtQuick
import qs.QuickXP

// Three-way policy toggle: follow shell / enabled / disabled (radio set).
Item {
  id: root

  property string value: ""
  property string followLabel: "Use shell default"
  property bool enabled: true
  signal activated(string id)

  readonly property real rowGap: 4

  implicitWidth: Math.max(followRadio.implicitWidth, onRadio.implicitWidth, offRadio.implicitWidth)
  implicitHeight: followRadio.height + onRadio.height + offRadio.height + rowGap * 2

  QtObject {
    id: group
    property var current: null
    function select(btn) {
      if (!root.enabled)
        return
      if (current && current !== btn)
        current.checked = false
      current = btn
      btn.checked = true
      root.activated(btn.valueId)
    }
  }

  function syncChecks() {
    followRadio.checked = root.value === ""
    onRadio.checked = root.value === "enabled"
    offRadio.checked = root.value === "disabled"
    if (followRadio.checked)
      group.current = followRadio
    else if (onRadio.checked)
      group.current = onRadio
    else if (offRadio.checked)
      group.current = offRadio
    else
      group.current = followRadio
  }

  onValueChanged: syncChecks()
  Component.onCompleted: syncChecks()

  Column {
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: root.rowGap

    XpRadioButton {
      id: followRadio
      property string valueId: ""
      width: parent.width
      text: root.followLabel
      enabled: root.enabled
      group: group
    }

    XpRadioButton {
      id: onRadio
      property string valueId: "enabled"
      width: parent.width
      text: "Enabled"
      enabled: root.enabled
      group: group
    }

    XpRadioButton {
      id: offRadio
      property string valueId: "disabled"
      width: parent.width
      text: "Disabled"
      enabled: root.enabled
      group: group
    }
  }
}
