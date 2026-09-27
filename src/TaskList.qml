import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    clip: true

    // KWin does not export zwlr-foreign-toplevel to clients other than
    // Plasma, so on KDE the window list comes from a KWin script.
    readonly property bool useKwin: {
        const desktop = String(Quickshell.env("XDG_CURRENT_DESKTOP") || "")
        const session = String(Quickshell.env("KDE_FULL_SESSION") || "")
        return desktop.toUpperCase().indexOf("KDE") !== -1 || session === "true"
    }
    readonly property string stateFile: Quickshell.statePath("quickxp-tasks.json")
    readonly property string scriptFile: Quickshell.shellPath("QuickXP/kwin/tasks.js")

    property var kwinTasks: []

    function applyTasks(text) {
        try {
            const parsed = JSON.parse(text)
            root.kwinTasks = Array.isArray(parsed) ? parsed : []
        } catch (error) {
            console.warn("QuickXP tasks:", error)
        }
    }

    readonly property int spacing: 3
    readonly property int maxButtonWidth: 160
    readonly property var windows: {
        if (root.useKwin) {
            const shown = []
            const rows = root.kwinTasks
            for (let i = 0; i < rows.length; ++i) {
                const row = rows[i]
                shown.push({
                    kwin: true,
                    windowId: row.id,
                    title: row.title || "",
                    appId: row.appId || "",
                    activated: !!row.active,
                    minimized: !!row.minimized,
                    parent: null
                })
            }
            return shown
        }

        const all = ToplevelManager.toplevels.values
        const shown = []
        for (let i = 0; i < all.length; ++i) {
            const toplevel = all[i]
            if (toplevel.parent == null)
                shown.push(toplevel)
        }
        return shown
    }

    Process {
        id: bridge

        running: root.useKwin
        command: ["/usr/bin/python3", Quickshell.shellPath("QuickXP/TasksBridge.py"), root.stateFile, root.scriptFile]

        stderr: SplitParser {
            onRead: data => console.warn("QuickXP tasks:", data.trim())
        }

        onStarted: taskFile.reload()
    }

    FileView {
        id: taskFile

        watchChanges: true
        printErrors: false
        blockLoading: false
        path: root.useKwin ? root.stateFile : ""

        onFileChanged: reload()
        onLoaded: root.applyTasks(text())
    }
    readonly property int buttonWidth: {
        const count = windows.length
        if (count === 0 || width <= 0)
            return 0
        const gaps = spacing * Math.max(0, count - 1)
        const share = (width - gaps) / count
        return Math.max(0, Math.min(maxButtonWidth, Math.floor(share)))
    }

    Row {
        id: row
        spacing: root.spacing
        height: parent.height

        Repeater {
            model: root.windows

            delegate: TaskButton {
                required property var modelData

                toplevel: modelData
                width: root.buttonWidth
                height: row.height
            }
        }
    }
}
