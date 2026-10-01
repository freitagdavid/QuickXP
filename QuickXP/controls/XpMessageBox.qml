import QtQuick
import Quickshell
import qs.QuickXP

// Simple XP-styled message box — text + OK / Cancel pushbuttons.
FloatingWindow {
  id: box

  property string text: ""
  property string informativeText: ""
  property bool showCancel: true
  signal accepted()
  signal rejected()

  title: "QuickXP"
  visible: false
  color: Theme.color("window", "#ECE9D8")
  minimumSize: Qt.size(
    Theme.value("messageBox", "minWidth", 280),
    Theme.value("messageBox", "minHeight", 120)
  )
  implicitWidth: Math.max(Theme.value("messageBox", "minWidth", 280), body.implicitWidth + 40)
  implicitHeight: Math.max(Theme.value("messageBox", "minHeight", 120), body.implicitHeight + buttonRow.height + 48)

  function open(message: string, showCancelButton: bool) {
    text = message
    if (showCancelButton !== undefined)
      showCancel = showCancelButton
    visible = true
  }

  function accept() {
    visible = false
    accepted()
  }

  function reject() {
    visible = false
    rejected()
  }

  Column {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 16
    spacing: 10

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      text: box.text
      color: Theme.color("windowText", "black")
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: Theme.size("fontSize", 11)
    }

    Text {
      width: parent.width
      visible: box.informativeText !== ""
      wrapMode: Text.WordWrap
      text: box.informativeText
      color: Theme.color("windowText", "black")
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: Theme.size("fontSize", 11)
    }
  }

  Row {
    id: buttonRow
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 12
    spacing: 8

    XpPushButton {
      text: "OK"
      defaulted: true
      onClicked: box.accept()
    }

    XpPushButton {
      visible: box.showCancel
      text: "Cancel"
      onClicked: box.reject()
    }
  }
}
