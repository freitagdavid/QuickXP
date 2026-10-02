import QtQuick
import qs.QuickXP

// Vertical banner on the root Classic Start menu (XP Classic: black at top → blue at bottom).
Item {
  id: root

  property string bannerText: "Linux"

  width: 28

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.color("classicStartBannerTop", "#000000") }
      GradientStop { position: 0.45; color: Theme.color("classicStartBannerMid", "#0A246A") }
      GradientStop { position: 1.0; color: Theme.color("classicStartBannerBottom", "#1E4A8C") }
    }
  }

  Text {
    id: label
    anchors.centerIn: parent
    width: parent.height - 12
    height: parent.width
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    // Bottom-to-top reading matches Classic Start.
    rotation: -90
    text: root.bannerText
    color: "#FFFFFF"
    elide: Text.ElideRight
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: 12
    font.bold: true
  }
}
