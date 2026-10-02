import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP

// XP Start user bar: STARTUSERPANEL skin + account tile + display name (STA-32).
Item {
  id: root

  property var host: null
  property string userName: {
    const full = String(Quickshell.env("LOGNAME") || Quickshell.env("USER") || "").trim()
    return full || "User"
  }
  property string facePath: {
    const home = String(Quickshell.env("HOME") || "").trim()
    if (!home)
      return ""
    return home + "/.face"
  }
  property bool faceAvailable: false

  FileView {
    id: faceProbe
    path: root.facePath
    printErrors: false
    blockLoading: false
    watchChanges: true
    onLoaded: root.faceAvailable = root.facePath.length > 0
    onLoadFailed: root.faceAvailable = false
  }

  readonly property int barHeight: Number(Theme.value("startPanel", "userBarHeight", 46))
  readonly property int tileSize: Number(Theme.value("startPanel", "tileSize", 42))

  height: barHeight
  implicitHeight: barHeight

  signal tileActivated()

  BorderImage {
    id: panelSkin
    anchors.fill: parent
    source: {
      const path = Theme.image("startUserPanelImage")
      return path ? ("file://" + path) : ""
    }
    border.left: 12
    border.right: 12
    border.top: 10
    border.bottom: 8
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  // Fallback when theme art is missing: black → Luna blue (matches Classic banner family).
  Rectangle {
    anchors.fill: parent
    visible: !panelSkin.visible
    gradient: Gradient {
      GradientStop { position: 0.0; color: Theme.color("classicStartBannerTop", "#000000") }
      GradientStop { position: 0.35; color: Theme.color("classicStartBannerMid", "#0A246A") }
      GradientStop { position: 1.0; color: Theme.color("classicStartBannerBottom", "#1E4A8C") }
    }
  }

  Item {
    id: tile
    anchors.left: parent.left
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: root.tileSize + 6
    height: root.tileSize + 6

    Image {
      id: tileFrame
      anchors.fill: parent
      source: {
        const path = Theme.image("startUserTileImage")
        return path ? ("file://" + path) : ""
      }
      fillMode: Image.Stretch
      smooth: true
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 3
      visible: !tileFrame.visible
      color: "#4A90D9"
      border.color: "#FFFFFF"
      border.width: 1
    }

    Image {
      id: face
      anchors.fill: parent
      anchors.margins: 5
      source: root.faceAvailable ? ("file://" + root.facePath) : ""
      fillMode: Image.PreserveAspectCrop
      smooth: true
      asynchronous: true
      visible: root.faceAvailable && status === Image.Ready
    }

    // Placeholder glyph when no ~/.face
    Text {
      anchors.centerIn: parent
      visible: !face.visible
      text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "?"
      color: "#FFFFFF"
      font.pixelSize: 18
      font.bold: true
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.tileActivated()
        if (root.host && typeof root.host.runAction === "function")
          root.host.runAction("user-tile")
      }
    }
  }

  Text {
    id: nameLabel
    anchors.left: tile.right
    anchors.leftMargin: 8
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    text: root.userName
    color: String(Theme.value("startPanel", "userNameColor", "#FFFFFF"))
    elide: Text.ElideRight
    font.family: Theme.value("fonts", "ui", "Tahoma")
    font.pixelSize: 14
    font.bold: true
    style: Text.Raised
    styleColor: String(Theme.value("startPanel", "userNameShadow", "#003366"))
  }
}
