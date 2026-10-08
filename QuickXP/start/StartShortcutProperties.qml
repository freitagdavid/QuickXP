import QtQuick
import Quickshell
import qs.QuickXP
import qs.QuickXP.controls

// Whisker-style shortcut editor. The caller saves a user .desktop override.
FloatingWindow {
  id: win

  property string entryId: ""

  signal saveRequested(string entryId, var fields)

  title: "Properties"
  visible: false
  color: Theme.color("window", "#ECE9D8")
  minimumSize: Qt.size(420, 248)
  implicitWidth: 440
  implicitHeight: 268

  function openWith(id, info) {
    win.entryId = String(id || "")
    nameField.text = info && info.name ? String(info.name) : ""
    commentField.text = info && info.comment ? String(info.comment) : ""
    commandField.text = info && info.exec ? String(info.exec) : ""
    workField.text = info && info.workingDirectory ? String(info.workingDirectory) : ""
    iconField.text = info && info.icon ? String(info.icon) : ""
    terminalBox.checked = !!(info && info.terminal)
    visible = true
  }

  function accept() {
    const id = win.entryId
    const fields = {
      name: nameField.text,
      comment: commentField.text,
      exec: commandField.text,
      workingDirectory: workField.text,
      icon: iconField.text,
      terminal: terminalBox.checked
    }
    visible = false
    win.saveRequested(id, fields)
  }

  function reject() {
    visible = false
  }

  component FieldRow: Row {
    property string label: ""
    property alias text: edit.text

    width: parent ? parent.width : 400
    height: 22
    spacing: 8

    Text {
      width: 120
      height: parent.height
      verticalAlignment: Text.AlignVCenter
      text: parent.label
      color: Theme.color("windowText", "black")
      font.family: Theme.value("fonts", "ui", "Tahoma")
      font.pixelSize: Theme.size("fontSize", 11)
    }

    XpEdit {
      id: edit
      width: parent.width - 128
    }
  }

  Column {
    id: form
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 6

    FieldRow { id: nameField; label: "Name:" }
    FieldRow { id: commentField; label: "Comment:" }
    FieldRow { id: commandField; label: "Command:" }
    FieldRow { id: workField; label: "Working directory:" }
    FieldRow { id: iconField; label: "Icon:" }

    XpCheckBox {
      id: terminalBox
      text: "Run in terminal"
      onToggled: terminalBox.checked = !terminalBox.checked
    }
  }

  Row {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 12
    spacing: 8

    XpPushButton {
      text: "OK"
      defaulted: true
      onClicked: win.accept()
    }

    XpPushButton {
      text: "Cancel"
      onClicked: win.reject()
    }
  }
}
