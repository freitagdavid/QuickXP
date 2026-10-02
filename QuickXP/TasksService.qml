pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One TasksBridge for the whole shell. TaskBar is per-screen; if each TaskList
// spawned its own Process they reap each other and stdin COMMAND/PREVIEW dies.
Singleton {
    id: root

    readonly property bool useKwin: {
        const desktop = String(Quickshell.env("XDG_CURRENT_DESKTOP") || "")
        const session = String(Quickshell.env("KDE_FULL_SESSION") || "")
        return desktop.toUpperCase().indexOf("KDE") !== -1 || session === "true"
    }
    readonly property string stateFile: Quickshell.statePath("quickxp-tasks.json")
    readonly property string scriptFile: Quickshell.shellPath("QuickXP/services/kwin/tasks.js")

    property var kwinTasks: []
    property int previewSerial: 0

    signal previewReply(int serial, string path)

    function applyTasks(text) {
        if (!text || !String(text).trim())
            return
        try {
            const parsed = JSON.parse(text)
            root.kwinTasks = Array.isArray(parsed) ? parsed : []
        } catch (error) {
            console.warn("QuickXP tasks:", error)
        }
    }

    function sendCommand(windowId, action) {
        const id = String(windowId || "").trim()
        const act = String(action || "").trim()
        if (!id || !act || !bridge.running)
            return
        bridge.write("COMMAND " + id + " " + act + "\n")
    }

    function nextPreviewSerial(): int {
        root.previewSerial += 1
        return root.previewSerial
    }

    function requestPreview(serial, windowId) {
        const id = String(windowId || "").trim()
        if (!id || !bridge.running)
            return
        bridge.write("PREVIEW " + String(serial) + " " + id + "\n")
    }

    function onBridgeStdout(data) {
        const line = String(data).trim()
        if (!line)
            return
        const parts = line.split(/\s+/)
        if (parts.length >= 2 && parts[0] === "PREVIEW") {
            const serial = Number(parts[1])
            const path = parts.length >= 3 && parts[2] !== "-" ? parts[2] : ""
            root.previewReply(serial, path)
            return
        }
        if (line)
            console.log("QuickXP tasks:", line)
    }

    Process {
        id: bridge

        // stdinEnabled must be true before running — once stdin is closed, write() is a no-op.
        stdinEnabled: true
        command: [
            "/usr/bin/python3",
            Quickshell.shellPath("QuickXP/services/TasksBridge.py"),
            root.stateFile,
            root.scriptFile
        ]
        running: root.useKwin

        stdout: SplitParser {
            onRead: data => root.onBridgeStdout(data)
        }

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
}
