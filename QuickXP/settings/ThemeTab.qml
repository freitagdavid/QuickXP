import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.QuickXP
import qs.QuickXP.controls

Item {
  id: root

  required property var draft

  property string importPath: ""
  property string importStatus: ""
  property bool importBusy: false
  property bool deleteBusy: false
  property string importStderr: ""

  // Lives under QuickXP/services so shellPath resolves when config only symlinks QuickXP/.
  readonly property string importScript: Quickshell.shellPath("QuickXP/services/import_xp_theme.py")
  readonly property string deleteScript: Quickshell.shellPath("QuickXP/services/delete_theme.py")
  readonly property string userThemesDir: ThemeRegistry.userThemesDir

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

  // Preview colors/images for the draft scheme (falls back to theme defaults).
  readonly property var selectedVariant: {
    const entry = root.selected
    if (entry === null)
      return null
    const sid = root.draft.themeScheme
    if (sid && entry.schemeData && entry.schemeData[sid]) {
      const variant = entry.schemeData[sid]
      return {
        path: entry.path,
        colors: variant.colors || entry.colors || ({}),
        images: variant.images || entry.images || ({}),
        sizes: variant.sizes || entry.sizes || ({})
      }
    }
    return entry
  }

  readonly property var schemeChoices: {
    const entry = root.selected
    if (entry === null || !Array.isArray(entry.schemes))
      return []
    return entry.schemes.map(function(s) {
      return { id: s.id, label: s.label || s.id }
    })
  }

  readonly property bool canDeleteSelected: {
    const entry = root.selected
    return entry !== null && entry.deletable === true && !root.importBusy && !root.deleteBusy
  }

  function defaultSchemeFor(entry: var): string {
    if (entry === undefined || entry === null)
      return ""
    if (entry.activeScheme)
      return String(entry.activeScheme)
    if (Array.isArray(entry.schemes) && entry.schemes.length)
      return String(entry.schemes[0].id || "")
    return ""
  }

  function selectTheme(slug: string): void {
    root.draft.theme = slug
    root.draft.themeScheme = root.defaultSchemeFor(ThemeRegistry.themeBySlug(slug))
  }

  readonly property var shellChoices: [
    { id: "", label: "Follow theme" },
    { id: "classic", label: "Windows Classic" },
    { id: "xp", label: "Windows XP" },
    { id: "vista", label: "Windows Vista" },
    { id: "win7", label: "Windows 7" }
  ]

  Component {
    id: toggleRadiosComponent
    XpToggleRadios {
      followLabel: "Use shell default"
    }
  }

  Component {
    id: choiceComboComponent
    XpGenerationSelect {
      followLabel: "Use shell default"
    }
  }

  function fileUrlToPath(url): string {
    let text = String(url)
    if (text.startsWith("file://")) {
      // file:///path → /path ; decode %20 etc.
      text = decodeURIComponent(text.slice(7))
      if (text.startsWith("//") && text.length > 2 && text[2] !== "/") {
        // file://hostname/path — drop hostname on local imports
        const slash = text.indexOf("/", 2)
        text = slash >= 0 ? text.slice(slash) : text
      }
    }
    return text
  }

  function showImportMessage(message: string, detail: string): void {
    noticePopup.anchorItem = importButton
    noticePopup.titleText = message || ""
    noticePopup.detailText = detail || ""
    noticePopup.visible = true
  }

  function dismissNotice(): void {
    noticePopup.visible = false
  }

  function beginImport(path: string): void {
    root.dismissNotice()
    root.importPath = path
    root.importStderr = ""
    root.importStatus = "Checking theme…"
    root.importBusy = true
    probeProc.exec([
      "/usr/bin/python3",
      root.importScript,
      "--probe",
      path
    ])
  }

  function runInstall(): void {
    if (root.importPath === "")
      return
    root.importStderr = ""
    root.importStatus = "Importing…"
    root.importBusy = true
    installProc.exec([
      "/usr/bin/python3",
      root.importScript,
      "--install",
      root.importPath,
      "--dest",
      root.userThemesDir
    ])
  }

  function parseJsonOutput(text: string): var {
    const trimmed = String(text).trim()
    if (trimmed === "")
      return null
    // Importer prints one JSON object; tolerate trailing noise.
    const start = trimmed.indexOf("{")
    const end = trimmed.lastIndexOf("}")
    if (start < 0 || end <= start)
      return null
    try {
      return JSON.parse(trimmed.slice(start, end + 1))
    } catch (error) {
      return null
    }
  }

  function handleProbeResult(text: string): void {
    const payload = root.parseJsonOutput(text)
    if (payload === null || payload === undefined) {
      root.importBusy = false
      root.importStatus = ""
      const detail = root.importStderr !== ""
        ? root.importStderr
        : "Could not parse probe result. Is the import script available?"
      root.showImportMessage("Import failed", detail)
      return
    }
    if (!payload.ok) {
      root.importBusy = false
      root.importStatus = ""
      const errs = payload.errors ? payload.errors.join("\n") : "Unsupported theme."
      root.showImportMessage("Cannot import this file", errs)
      return
    }
    // Prefer the resolved .msstyles path from probe (folder → file).
    if (payload.path)
      root.importPath = payload.path
    const n = Array.isArray(payload.schemes) ? payload.schemes.length : 0
    root.importStatus = n > 1
      ? ("Importing with " + n + " color schemes…")
      : "Importing…"
    runInstall()
  }

  function handleInstallResult(text: string): void {
    root.importBusy = false
    const payload = root.parseJsonOutput(text)
    if (payload === null || payload === undefined) {
      root.importStatus = ""
      const detail = root.importStderr !== ""
        ? root.importStderr
        : "Could not parse importer output."
      root.showImportMessage("Import failed", detail)
      return
    }
    if (!payload.ok) {
      root.importStatus = ""
      const errs = payload.errors ? payload.errors.join("\n") : "Import failed."
      root.showImportMessage("Import failed", errs)
      return
    }
    if (payload.entry) {
      payload.entry.deletable = true
      ThemeRegistry.upsertTheme(payload.entry)
    }
    ThemeRegistry.refresh()
    if (payload.slug)
      root.selectTheme(payload.slug)
    const schemeCount = payload.entry && Array.isArray(payload.entry.schemes)
      ? payload.entry.schemes.length
      : (Array.isArray(payload.schemes) ? payload.schemes.length : 0)
    const warns = (payload.warnings && payload.warnings.length)
      ? payload.warnings.slice(0, 8).join("\n")
      : ""
    const name = payload.theme && payload.theme.name ? payload.theme.name : payload.slug
    const replaced = payload.replaced === true
    const verb = replaced ? "Updated" : "Imported"
    root.importStatus = schemeCount > 1
      ? (verb + " “" + name + "” with " + schemeCount + " schemes. Pick a scheme, then Apply.")
      : (verb + " “" + name + "”. Apply to use it.")
    if (warns)
      showImportMessage(verb + " with warnings", warns)
    else
      showImportMessage(replaced ? "Theme updated" : "Theme imported", root.importStatus)
  }

  function confirmDelete(): void {
    const entry = root.selected
    if (entry === null || !entry.deletable)
      return
    deleteConfirm.anchorItem = deleteButton
    deleteConfirm.message = "Delete “" + (entry.name || entry.slug) + "”?"
    deleteConfirm.visible = true
  }

  function dismissDeleteConfirm(): void {
    deleteConfirm.visible = false
  }

  function runDelete(): void {
    const entry = root.selected
    if (entry === null || !entry.deletable)
      return
    root.deleteBusy = true
    root.importStatus = "Deleting…"
    deleteProc.exec([
      "/usr/bin/python3",
      root.deleteScript,
      "--dest",
      root.userThemesDir,
      entry.slug
    ])
  }

  function handleDeleteResult(text: string): void {
    root.deleteBusy = false
    const payload = root.parseJsonOutput(text)
    if (payload === null || payload === undefined || !payload.ok) {
      const detail = (payload && payload.errors)
        ? payload.errors.join("\n")
        : (root.importStderr !== "" ? root.importStderr : "Delete failed.")
      root.importStatus = ""
      root.showImportMessage("Could not delete theme", detail)
      return
    }
    const removed = payload.slug || (root.selected && root.selected.slug) || ""
    ThemeRegistry.removeTheme(removed)
    ThemeRegistry.refresh()
    if (root.draft.theme === removed) {
      const fallback = ThemeRegistry.themes.length ? ThemeRegistry.themes[0].slug : "luna"
      root.selectTheme(fallback)
    }
    root.importStatus = "Deleted “" + removed + "”."
  }

  FileDialog {
    id: importDialog
    title: "Import visual style"
    nameFilters: ["Windows XP visual styles (*.msstyles)", "All files (*)"]
    fileMode: FileDialog.OpenFile
    onAccepted: {
      const path = root.fileUrlToPath(selectedFile)
      if (path)
        root.beginImport(path)
    }
  }

  Process {
    id: probeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleProbeResult(text)
    }
    stderr: SplitParser {
      onRead: data => {
        const line = data.trim()
        if (line === "")
          return
        root.importStderr = root.importStderr === "" ? line : (root.importStderr + "\n" + line)
        console.warn("QuickXP import probe:", line)
      }
    }
  }

  Process {
    id: installProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleInstallResult(text)
    }
    stderr: SplitParser {
      onRead: data => {
        const line = data.trim()
        if (line === "")
          return
        root.importStderr = root.importStderr === "" ? line : (root.importStderr + "\n" + line)
        console.warn("QuickXP import:", line)
      }
    }
  }

  Process {
    id: deleteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleDeleteResult(text)
    }
    stderr: SplitParser {
      onRead: data => {
        const line = data.trim()
        if (line === "")
          return
        root.importStderr = root.importStderr === "" ? line : (root.importStderr + "\n" + line)
        console.warn("QuickXP delete theme:", line)
      }
    }
  }

  PopupWindow {
    id: noticePopup
    property string titleText: ""
    property string detailText: ""
    property Item anchorItem: null

    visible: false
    color: Theme.color("window", "#ECE9D8")
    grabFocus: true
    implicitWidth: Math.min(320, Math.max(220, noticeBody.implicitWidth + 20))
    implicitHeight: noticeBody.implicitHeight + 20

    anchor.item: noticePopup.anchorItem
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: 2

    onClosed: visible = false

    Rectangle {
      anchors.fill: parent
      color: Theme.color("window", "#ECE9D8")
      border.width: 1
      border.color: Theme.value("edit", "border", "#7F9DB9")

      Column {
        id: noticeBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 8

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: noticePopup.titleText
          color: Theme.color("windowText", "black")
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)
          font.bold: true
        }

        Text {
          width: parent.width
          visible: noticePopup.detailText !== ""
          wrapMode: Text.WordWrap
          maximumLineCount: 8
          elide: Text.ElideRight
          text: noticePopup.detailText
          color: Theme.color("windowText", "black")
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)
          opacity: 0.85
        }

        Item {
          width: parent.width
          height: noticeOk.height

          XpPushButton {
            id: noticeOk
            anchors.right: parent.right
            text: "OK"
            defaulted: true
            onClicked: root.dismissNotice()
          }
        }
      }
    }
  }

  PopupWindow {
    id: deleteConfirm
    property string message: "Delete this theme?"
    property Item anchorItem: null

    visible: false
    color: Theme.color("window", "#ECE9D8")
    grabFocus: true
    implicitWidth: Math.max(220, confirmBody.implicitWidth + 20)
    implicitHeight: confirmBody.implicitHeight + 20

    anchor.item: deleteConfirm.anchorItem
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: 2

    onClosed: visible = false

    Rectangle {
      anchors.fill: parent
      color: Theme.color("window", "#ECE9D8")
      border.width: 1
      border.color: Theme.value("edit", "border", "#7F9DB9")

      Column {
        id: confirmBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 10

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: deleteConfirm.message
          color: Theme.color("windowText", "black")
          font.family: Theme.value("fonts", "ui", "Tahoma")
          font.pixelSize: Theme.size("fontSize", 11)
        }

        Item {
          width: parent.width
          height: confirmButtons.height

          Row {
            id: confirmButtons
            anchors.right: parent.right
            spacing: 8

            XpPushButton {
              text: "Delete"
              defaulted: true
              onClicked: {
                root.dismissDeleteConfirm()
                root.runDelete()
              }
            }

            XpPushButton {
              text: "Cancel"
              onClicked: root.dismissDeleteConfirm()
            }
          }
        }
      }
    }
  }

  Flickable {
    id: themeFlick
    anchors.fill: parent
    anchors.margins: 12
    contentWidth: width
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    boundsMovement: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    readonly property real maxContentY: Math.max(0, contentHeight - height)
    onContentYChanged: {
      if (contentY < 0)
        contentY = 0
      else if (contentY > maxContentY)
        contentY = maxContentY
      DropdownGate.dismiss()
    }

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
          boundsBehavior: Flickable.StopAtBounds
          boundsMovement: Flickable.StopAtBounds
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
              onClicked: root.selectTheme(modelData.slug)
            }
          }
        }
      }

      Row {
        spacing: 8

        XpPushButton {
          id: importButton
          text: "Import…"
          enabled: !root.importBusy && !root.deleteBusy
          onClicked: importDialog.open()
        }

        XpPushButton {
          id: deleteButton
          text: "Delete"
          enabled: root.canDeleteSelected
          onClicked: root.confirmDelete()
        }
      }

      Text {
        width: parent.width
        visible: root.importStatus !== ""
        wrapMode: Text.WordWrap
        text: root.importStatus
        color: Theme.color("windowText", "black")
        font.family: Theme.value("fonts", "ui", "Tahoma")
        font.pixelSize: Theme.size("fontSize", 11)
        opacity: 0.8
      }

      XpGroupBox {
        width: parent.width
        height: schemeRow.height + 28
        title: "Color scheme"
        visible: root.schemeChoices.length > 0

        Row {
          id: schemeRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Scheme:"
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
          }

          XpGenerationSelect {
            width: 200
            value: root.draft.themeScheme
            followLabel: "Default"
            choices: root.schemeChoices
            enabled: !root.importBusy && !root.deleteBusy && root.schemeChoices.length > 1
            onActivated: function(id) {
              root.draft.themeScheme = id
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
            const entry = root.selectedVariant
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

            readonly property string barSource: root.themeImageUrl(root.selectedVariant, "taskbarImage")
            readonly property string startSource: root.themeImageUrl(root.selectedVariant, "startButtonImage")

            Rectangle {
              anchors.fill: parent
              color: {
                const entry = root.selectedVariant
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
            text: "Each item follows the shell generation unless you pick what that feature should do."
            color: Theme.color("windowText", "black")
            font.family: Theme.value("fonts", "ui", "Tahoma")
            font.pixelSize: Theme.size("fontSize", 11)
            opacity: 0.75
          }

          Repeater {
            model: GenerationPolicy.items

            delegate: Column {
              id: overrideRow
              required property var modelData

              width: overrideColumn.width
              spacing: 4

              readonly property string overrideValue: {
                const bag = root.draft.generationOverrides
                const key = modelData.id
                if (bag === undefined || bag === null || bag[key] === undefined || bag[key] === null)
                  return ""
                return GenerationPolicy.normalizeOverride(key, bag[key])
              }

              Text {
                width: parent.width
                text: modelData.label
                color: Theme.color("windowText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
              }

              Loader {
                id: controlLoader
                width: parent.width
                // Only create the matching control (avoids unused floating popups).
                sourceComponent: modelData.kind === "toggle"
                  ? toggleRadiosComponent
                  : choiceComboComponent

                onLoaded: {
                  item.width = width
                  item.value = overrideRow.overrideValue
                  if (overrideRow.modelData.kind !== "toggle")
                    item.choices = GenerationPolicy.choicesFor(overrideRow.modelData.id, "Use shell default")
                  item.activated.connect(function(id) {
                    root.draft.setOverride(overrideRow.modelData.id, id)
                  })
                }

                Binding {
                  target: controlLoader.item
                  when: controlLoader.status === Loader.Ready
                  property: "value"
                  value: overrideRow.overrideValue
                }
              }

              Text {
                width: parent.width
                visible: modelData.hint !== undefined && modelData.hint !== ""
                wrapMode: Text.WordWrap
                text: modelData.hint
                color: Theme.color("windowText", "black")
                font.family: Theme.value("fonts", "ui", "Tahoma")
                font.pixelSize: Theme.size("fontSize", 11)
                opacity: 0.55
              }
            }
          }
        }
      }

    }
  }
}
