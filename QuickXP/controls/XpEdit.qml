import QtQuick
import qs.QuickXP

// [edit] BorderFill — FillColor / BorderColor from theme (NORMALBLUE.ini).
Item {
  id: root

  property alias text: field.text
  property string placeholderText: ""
  property alias readOnly: field.readOnly
  property alias echoMode: field.echoMode
  property alias validator: field.validator
  property alias inputMethodHints: field.inputMethodHints
  property bool enabled: true
  signal accepted()
  signal textEdited()
  // Fired from the inner TextInput before default key handling; set event.accepted to consume.
  signal keyPressed(var event)

  implicitWidth: 120
  implicitHeight: 21

  readonly property bool hot: area.containsMouse || field.activeFocus

  Rectangle {
    anchors.fill: parent
    color: {
      if (!root.enabled)
        return Theme.value("edit", "disabledFill", "#EBEBE4")
      if (field.readOnly)
        return Theme.value("edit", "readOnlyFill", "#EBEBE4")
      return Theme.value("edit", "fill", "#FFFFFF")
    }
    border.width: 1
    border.color: Theme.value("edit", "border", "#7F9DB9")
  }

  Text {
    anchors.fill: parent
    anchors.leftMargin: 3
    anchors.rightMargin: 3
    verticalAlignment: Text.AlignVCenter
    visible: field.text.length === 0 && !field.activeFocus && root.placeholderText !== ""
    text: root.placeholderText
    color: Theme.value("edit", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    elide: Text.ElideRight
  }

  TextInput {
    id: field
    anchors.fill: parent
    anchors.leftMargin: 3
    anchors.rightMargin: 3
    verticalAlignment: TextInput.AlignVCenter
    clip: true
    color: root.enabled
      ? Theme.color("windowText", "black")
      : Theme.value("edit", "disabledText", "#A1A192")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
    enabled: root.enabled
    selectByMouse: true
    onAccepted: root.accepted()
    onTextEdited: root.textEdited()
    Keys.onPressed: (event) => root.keyPressed(event)
  }

  MouseArea {
    id: area
    anchors.fill: parent
    enabled: root.enabled && !field.activeFocus
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    onClicked: field.forceActiveFocus()
  }

  XpFocusRect {
    active: field.activeFocus
  }

  function forceActiveFocus() {
    field.forceActiveFocus()
  }
}
