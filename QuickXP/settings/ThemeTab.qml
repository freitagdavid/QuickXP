import QtQuick
import qs.QuickXP
import qs.QuickXP.controls

Item {
  id: root

  required property var draft

  function themeImageUrl(entry: var, key: string): string {
    if (entry === undefined || entry === null || !entry.images)
      return ""
    const value = entry.images[key]
    if (value === undefined || value === null || value === "")
      return ""
    const path = String(value)
    if (path.startsWith("/") || path.startsWith("file:"))
      return path.startsWith("file:") ? path : "file://" + path
    return "file://" + entry.path + "/" + path
  }

  readonly property var selected: {
    const entry = ThemeRegistry.themeBySlug(draft.theme)
    return entry === undefined ? null : entry
  }

  Column {
    anchors.fill: parent
    anchors.margins: 12
    spacing: 10

    XpGroupBox {
      width: parent.width
      height: 168
      title: "Theme"

      ListView {
        id: list
        anchors.fill: parent
        clip: true
        model: ThemeRegistry.themes
        currentIndex: {
          const slug = root.draft.theme
          const themes = ThemeRegistry.themes
          for (let i = 0; i < themes.length; ++i) {
            if (themes[i].slug === slug)
              return i
          }
          return -1
        }

        Rectangle {
          anchors.fill: parent
          z: -1
          color: Theme.value("edit", "fill", "#FFFFFF")
          border.width: 1
          border.color: Theme.value("edit", "border", "#7F9DB9")
        }

        delegate: Item {
          id: row
          required property var modelData
          required property int index

          width: list.width
          height: 18

          readonly property bool selected: modelData.slug === root.draft.theme

          Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: row.selected ? Theme.color("highlight", "#316AC5") : "transparent"
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.name || modelData.slug
            color: row.selected
              ? Theme.color("highlightText", "white")
              : Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.draft.theme = modelData.slug
          }
        }
      }
    }

    XpGroupBox {
      width: parent.width
      height: 72
      title: "Sample"

      Rectangle {
        anchors.fill: parent
        color: {
          const entry = root.selected
          if (entry && entry.colors && entry.colors.desktop)
            return entry.colors.desktop
          return Theme.color("desktop", "#3A6EA5")
        }
        border.width: 1
        border.color: Theme.value("edit", "border", "#7F9DB9")
        clip: true

        Item {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 28

          readonly property string barSource: root.themeImageUrl(root.selected, "taskbarImage")
          readonly property string startSource: root.themeImageUrl(root.selected, "startButtonImage")

          Rectangle {
            anchors.fill: parent
            color: {
              const entry = root.selected
              if (entry && entry.colors && entry.colors.taskbar)
                return entry.colors.taskbar
              return Theme.color("taskbar", "#245EDC")
            }
            visible: parent.barSource === ""
          }

          BorderImage {
            anchors.fill: parent
            source: parent.barSource
            border.top: 15
            border.bottom: 11
            horizontalTileMode: BorderImage.Repeat
            verticalTileMode: BorderImage.Stretch
            visible: parent.barSource !== ""
          }

          Image {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: height * 2.8
            source: parent.startSource
            fillMode: Image.PreserveAspectFit
            visible: parent.startSource !== ""
            smooth: false
          }
        }
      }
    }

    XpCheckBox {
      text: "Match window borders"
      checked: root.draft.matchWindowBorders
      onToggled: root.draft.matchWindowBorders = !root.draft.matchWindowBorders
    }

    Row {
      spacing: 8

      XpPushButton {
        text: "Import…"
        enabled: false
      }

      XpPushButton {
        text: "Delete"
        enabled: false
      }
    }
  }
}
