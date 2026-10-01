import QtQuick
import qs.QuickXP

Item {
  property string message: "This page will be available in a later update."

  Text {
    anchors.centerIn: parent
    width: parent.width - 32
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.WordWrap
    text: message
    color: Theme.color("windowText", "black")
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: Theme.size("fontSize", 11)
  }
}
