import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.QuickXP
import qs.QuickXP.controls

FloatingWindow {
  id: window

  title: "Display Properties"
  visible: false
  color: Theme.color("window", "#ECE9D8")
  minimumSize: Qt.size(420, 480)
  implicitWidth: 460
  implicitHeight: 520

  property alias draft: draft
  property string auroraeStatus: ""

  SettingsDraft {
    id: draft
  }

  readonly property string syncAuroraeScript: Quickshell.shellPath("QuickXP/services/sync_aurorae.py")
  readonly property string generateAuroraeScript: Quickshell.shellPath("QuickXP/services/generate_aurorae.py")

  Process {
    id: auroraeSyncProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const payload = JSON.parse(String(text).trim())
          if (payload.skipped)
            window.auroraeStatus = "Window borders: skipped (not Plasma/KWin?)"
          else if (payload.ok)
            window.auroraeStatus = "Window borders: matched to theme"
          else
            window.auroraeStatus = "Window borders: "
              + ((payload.errors && payload.errors[0]) || "sync failed")
        } catch (error) {
          window.auroraeStatus = "Window borders: invalid sync response"
        }
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP aurorae sync:", data.trim())
    }
  }

  function syncAuroraeForDraft(): void {
    if (!draft.matchWindowBorders) {
      window.auroraeStatus = ""
      return
    }
    const entry = ThemeRegistry.themeBySlug(draft.theme)
    if (entry === undefined || entry === null || !entry.path) {
      window.auroraeStatus = "Window borders: theme path missing"
      return
    }
    const themeRoot = String(entry.path)
    // Generate package if missing, then install + select.
    const hasDeco = entry.hasAurorae === true
    if (!hasDeco) {
      generateThenSyncProc.exec([
        "/usr/bin/python3",
        window.generateAuroraeScript,
        themeRoot,
        "--slug",
        draft.theme
      ])
      return
    }
    auroraeSyncProc.exec([
      "/usr/bin/python3",
      window.syncAuroraeScript,
      "--theme-root",
      themeRoot
    ])
  }

  Process {
    id: generateThenSyncProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          const payload = JSON.parse(String(text).trim())
          if (!payload.ok) {
            window.auroraeStatus = "Window borders: "
              + ((payload.errors && payload.errors[0]) || "generate failed")
            return
          }
        } catch (error) {
          window.auroraeStatus = "Window borders: generate failed"
          return
        }
        const entry = ThemeRegistry.themeBySlug(draft.theme)
        if (entry === undefined || entry === null || !entry.path)
          return
        ThemeRegistry.refresh()
        auroraeSyncProc.exec([
          "/usr/bin/python3",
          window.syncAuroraeScript,
          "--theme-root",
          String(entry.path)
        ])
      }
    }
    stderr: SplitParser {
      onRead: data => console.warn("QuickXP aurorae generate:", data.trim())
    }
  }

  readonly property var tabs: [
    { id: "theme", title: "Theme", enabled: true },
    { id: "taskbar", title: "Taskbar", enabled: true },
    { id: "start", title: "Start Menu", enabled: false },
    { id: "desktop", title: "Desktop", enabled: false },
    { id: "notify", title: "Notification Area", enabled: false },
    { id: "about", title: "About", enabled: false }
  ]

  function selectTab(tabId: string) {
    const list = window.tabs
    let chosen = "theme"
    for (let i = 0; i < list.length; ++i) {
      if (list[i].id === tabId && list[i].enabled) {
        chosen = tabId
        break
      }
    }
    draft.activeTab = chosen
  }

  function loadDraft() {
    draft.loadFromConfig()
    ThemeRegistry.refresh()
  }

  function apply() {
    draft.applyToConfig()
    window.syncAuroraeForDraft()
  }

  function accept() {
    apply()
    Settings.close()
  }

  function cancel() {
    Settings.close()
  }

  onVisibleChanged: {
    if (!visible) {
      Config.options.lastSettingsTab = draft.activeTab
      DropdownGate.dismiss()
    }
  }

  Item {
    anchors.fill: parent

    // Dialog client area — XP uses ~11px margins around the property sheet.
    Column {
      anchors.fill: parent
      anchors.margins: 11
      spacing: 0

      Item {
        id: sheet
        width: parent.width
        height: parent.height - buttonRow.height - 10

        // Tab buttons sit on top of the pane edge.
        Row {
          id: tabBar
          z: 2
          x: 2
          y: 0
          height: 22
          spacing: -1

          Repeater {
            model: window.tabs

            delegate: XpTabButton {
              required property var modelData

              // Inactive tabs sit 2px lower so the selected tab covers the pane edge.
              y: selected ? 0 : 2
              text: modelData.title
              enabled: modelData.enabled
              selected: draft.activeTab === modelData.id
              onClicked: {
                DropdownGate.dismiss()
                draft.activeTab = modelData.id
              }
            }
          }
        }

        // Tab pane body with Luna TabPaneEdge 9-slice.
        Item {
          id: pane
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: 20
          anchors.bottom: parent.bottom

          ThemeStrip {
            anchors.fill: parent
            imageKey: "tabPaneEdgeImage"
            frames: 1
            frame: 0
            borderLeft: 2
            borderRight: 4
            borderTop: 2
            borderBottom: 4
          }

          // Interior fill matches Tab.Body fill hint (#FBFBFD) / window beige.
          Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 4
            anchors.topMargin: 2
            anchors.bottomMargin: 4
            color: Theme.value("tab", "bodyFill", "#FBFBFD")
          }

          StackLayout {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 5
            anchors.topMargin: 3
            anchors.bottomMargin: 5
            currentIndex: {
              const list = window.tabs
              for (let i = 0; i < list.length; ++i) {
                if (list[i].id === draft.activeTab)
                  return i
              }
              return 0
            }

            ThemeTab {
              draft: window.draft
            }

            TaskbarTab {
              draft: window.draft
            }

            PlaceholderTab {
              message: "Start Menu options will appear here once classic and XP Start menus are available."
            }

            PlaceholderTab {
              message: "Desktop wallpaper and icon options will appear here with the Desktop epic."
            }

            PlaceholderTab {
              message: "Notification Area options will appear here with tray controls and the notification queue."
            }

            PlaceholderTab {
              message: "QuickXP Settings\nTheme folder: " + Quickshell.shellPath("QuickXP/themes")
            }
          }
        }
      }

      Item {
        id: buttonRow
        width: parent.width
        height: 23

        Row {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          spacing: 8

          XpPushButton {
            text: "OK"
            defaulted: true
            onClicked: window.accept()
          }

          XpPushButton {
            text: "Cancel"
            onClicked: window.cancel()
          }

          XpPushButton {
            text: "Apply"
            enabled: draft.dirty
            onClicked: window.apply()
          }
        }
      }
    }

    // PopupWindow grab does not see clicks on this FloatingWindow; catch them here.
    XpDropdownDismiss {}
  }
}
