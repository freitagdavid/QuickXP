import QtQuick
import Quickshell
import Quickshell.Io
import qs.QuickXP

// XP Start user bar — STARTUSERPANEL skin + account tile (theme-driven).
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
  // CC0 Staunton crop — see start/assets/SOURCES.txt (not the Corbis XP chess.bmp).
  readonly property string defaultFacePath: Quickshell.shellPath("QuickXP/start/assets/default-user-chess.png")
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

  readonly property string faceSource: {
    if (root.faceAvailable && root.facePath.length > 0)
      return "file://" + root.facePath
    if (root.defaultFacePath.length > 0)
      return "file://" + root.defaultFacePath
    return ""
  }

  readonly property int barHeight: Number(Theme.value("startPanel", "userBarHeight", 64))
  // Account picture content size (XP default 48); outer chrome comes from UserTileBackground.
  readonly property int tileSize: Number(Theme.value("startPanel", "tileSize", 48))
  readonly property int tileContentLeft: Number(Theme.value("startPanel", "tileContentLeft", 8))
  readonly property int tileContentRight: Number(Theme.value("startPanel", "tileContentRight", 6))
  readonly property int tileContentTop: Number(Theme.value("startPanel", "tileContentTop", 8))
  readonly property int tileContentBottom: Number(Theme.value("startPanel", "tileContentBottom", 6))
  readonly property int tileOuterWidth: root.tileSize + root.tileContentLeft + root.tileContentRight
  readonly property int tileOuterHeight: root.tileSize + root.tileContentTop + root.tileContentBottom

  height: barHeight
  implicitHeight: barHeight

  signal tileActivated()

  // Opaque underlay so magenta-keyed corners never show MFU orange through the header.
  Rectangle {
    anchors.fill: parent
    color: GenerationPolicy.glass
      ? "transparent"
      : String(Theme.value("startPanel", "userFill", Theme.color("titleActive", "#0054E3")))
  }

  BorderImage {
    id: panelSkin
    anchors.fill: parent
    source: {
      const path = Theme.image("startUserPanelImage")
      return path ? ("file://" + path) : ""
    }
    border.left: Number(Theme.value("startPanel", "userBorderLeft", 59))
    border.right: Number(Theme.value("startPanel", "userBorderRight", 60))
    border.top: Number(Theme.value("startPanel", "userBorderTop", 62))
    border.bottom: Math.max(0, Number(Theme.value("startPanel", "userBorderBottom", 0)))
    horizontalTileMode: BorderImage.Stretch
    verticalTileMode: BorderImage.Stretch
    visible: status === Image.Ready
  }

  // StartPanel.UserPicture — theme UserTileBackground frame with face in ContentMargins.
  Item {
    id: tile
    anchors.left: parent.left
    anchors.leftMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    width: root.tileOuterWidth
    height: root.tileOuterHeight

    BorderImage {
      id: tileFrame
      anchors.fill: parent
      source: {
        const path = Theme.image("startUserTileImage")
        return path ? ("file://" + path) : ""
      }
      border.left: Number(Theme.value("startPanel", "tileBorderLeft", 6))
      border.right: Number(Theme.value("startPanel", "tileBorderRight", 10))
      border.top: Number(Theme.value("startPanel", "tileBorderTop", 6))
      border.bottom: Number(Theme.value("startPanel", "tileBorderBottom", 10))
      horizontalTileMode: BorderImage.Stretch
      verticalTileMode: BorderImage.Stretch
      smooth: true
      visible: status === Image.Ready
    }

    Rectangle {
      anchors.fill: parent
      visible: !tileFrame.visible
      color: String(Theme.value("startPanel", "tileFill", "#CCD6EB"))
      radius: 4
    }

    Image {
      id: face
      anchors.fill: parent
      anchors.leftMargin: root.tileContentLeft
      anchors.rightMargin: root.tileContentRight
      anchors.topMargin: root.tileContentTop
      anchors.bottomMargin: root.tileContentBottom
      source: root.faceSource
      fillMode: Image.PreserveAspectCrop
      smooth: true
      asynchronous: true
      visible: status === Image.Ready && root.faceSource.length > 0
    }

    Text {
      anchors.fill: face
      visible: !face.visible
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : "?"
      color: String(Theme.value("startPanel", "userNameColor", "#FFFFFF"))
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
    styleColor: String(Theme.value("startPanel", "userNameShadow", "#09428B"))
  }
}
