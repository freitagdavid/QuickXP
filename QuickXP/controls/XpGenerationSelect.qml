import QtQuick
import qs.QuickXP

// Compact XP-styled choice control (cycles open list). value "" means followDefault.
Item {
  id: root

  property string value: ""
  property string followLabel: "Use shell default"
  property var choices: [
    { id: "", label: followLabel },
    { id: "classic", label: "Windows Classic" },
    { id: "xp", label: "Windows XP" },
    { id: "vista", label: "Windows Vista" },
    { id: "win7", label: "Windows 7" }
  ]
  property bool enabled: true
  signal activated(string id)

  readonly property string displayLabel: {
    const list = root.choices
    for (let i = 0; i < list.length; ++i) {
      if (list[i].id === root.value)
        return list[i].label
    }
    return GenerationPolicy.labelFor(root.value, root.followLabel)
  }

  implicitWidth: Math.max(160, Math.min(220, button.implicitWidth))
  implicitHeight: open ? button.height + listBox.height + 2 : button.height

  XpPushButton {
    id: button
    width: parent.width
    text: root.displayLabel + (open ? " ▲" : " ▼")
    enabled: root.enabled
    onClicked: open = !open
  }

  property bool open: false

  Rectangle {
    id: listBox
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: button.bottom
    anchors.topMargin: 2
    height: open ? column.height + 2 : 0
    visible: open
    color: Theme.value("edit", "fill", "#FFFFFF")
    border.width: 1
    border.color: Theme.value("edit", "border", "#7F9DB9")
    clip: true
    z: 10

    Column {
      id: column
      width: parent.width
      y: 1

      Repeater {
        model: root.choices

        delegate: Item {
          id: row
          required property var modelData

          width: column.width
          height: 18

          readonly property bool selected: modelData.id === root.value

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: row.selected ? Theme.color("highlight", "#316AC5") : "transparent"
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.label
            color: row.selected
              ? Theme.color("highlightText", "white")
              : Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              root.activated(modelData.id)
              root.open = false
            }
          }
        }
      }
    }
  }
}
