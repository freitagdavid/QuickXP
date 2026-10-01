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

  readonly property var shellChoices: [
    { id: "", label: "Follow theme" },
    { id: "classic", label: "Windows Classic" },
    { id: "xp", label: "Windows XP" },
    { id: "vista", label: "Windows Vista" },
    { id: "win7", label: "Windows 7" }
  ]

  readonly property var overrideChoices: [
    { id: "", label: "Use shell default" },
    { id: "classic", label: "Windows Classic" },
    { id: "xp", label: "Windows XP" },
    { id: "vista", label: "Windows Vista" },
    { id: "win7", label: "Windows 7" }
  ]

  Flickable {
    anchors.fill: parent
    anchors.margins: 12
    contentWidth: width
    contentHeight: column.height
    clip: true

    Column {
      id: column
      width: parent.width
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
              text: {
                const name = modelData.name || modelData.slug
                const gen = modelData.generation
                if (gen === undefined || gen === null || gen === "")
                  return name
                return name + " (" + gen + ")"
              }
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

      XpGroupBox {
        width: parent.width
        height: shellRow.height + 28
        title: "Shell generation"

        Column {
          id: shellRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 6

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Defaults Start, Quick Launch, grouping, notifications, and other layout rules. Theme assets still come from the selected theme."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
            opacity: 0.75
          }

          Row {
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Generation:"
              color: Theme.color("windowText", "black")
              font.family: Theme.value("fonts", "ui", "Tahoma")
              font.pixelSize: Theme.size("fontSize", 11)
            }

            XpGenerationSelect {
              width: 180
              value: root.draft.generation
              followLabel: "Follow theme"
              choices: root.shellChoices
              onActivated: function(id) {
                root.draft.generation = id
              }
            }
          }

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: {
              const themeGen = root.selected && root.selected.generation
                ? root.selected.generation
                : Theme.generation
              const effective = root.draft.generation === ""
                ? themeGen
                : root.draft.generation
              return "Effective now: " + GenerationPolicy.labelFor(effective, themeGen)
                + (root.draft.generation === "" ? " (from theme)" : "")
            }
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }
        }
      }

      XpGroupBox {
        width: parent.width
        height: overrideColumn.height + 28
        title: "Feature overrides"

        Column {
          id: overrideColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 8

          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Each item follows the shell generation unless you pick an override."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
            opacity: 0.75
          }

          Repeater {
            model: GenerationPolicy.items

            delegate: Row {
              id: overrideRow
              required property var modelData

              width: overrideColumn.width
              spacing: 8

              Text {
                width: Math.min(160, overrideRow.width * 0.42)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                elide: Text.ElideRight
                color: Theme.color("windowText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
              }

              XpGenerationSelect {
                width: Math.min(180, overrideRow.width - 168)
                value: {
                  const bag = root.draft.generationOverrides
                  const key = modelData.id
                  if (bag === undefined || bag === null || bag[key] === undefined || bag[key] === null)
                    return ""
                  return bag[key]
                }
                followLabel: "Use shell default"
                choices: root.overrideChoices
                onActivated: function(id) {
                  root.draft.setOverride(modelData.id, id)
                }
              }
            }
          }
        }
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
}
