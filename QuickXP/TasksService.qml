pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "TasksModel.js" as TasksModel

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
        // Ignore empty reads from a non-atomic truncate/write race.
        if (!text || !String(text).trim())
            return
        root.kwinTasks = TasksModel.parseWindowsJson(text)
    }

    function sendCommand(windowId, action) {
        if (!bridge.running)
            return
        const line = TasksModel.formatCommandLine(windowId, action)
        if (!line)
            return
        bridge.write(line)
    }

    function nextPreviewSerial(): int {
        root.previewSerial += 1
        return root.previewSerial
    }

    function requestPreview(serial, windowId) {
        if (!bridge.running)
            return
        const line = TasksModel.formatPreviewRequest(serial, windowId)
        if (!line)
            return
        bridge.write(line)
    }

    function toggleShowDesktop() {
        if (!bridge.running)
            return
        bridge.write(TasksModel.formatShowDesktop())
    }

    function onBridgeStdout(data) {
        const line = String(data).trim()
        if (!line)
            return
        const reply = TasksModel.parsePreviewReply(line)
        if (reply !== null) {
            root.previewReply(reply.serial, reply.path)
            return
        }
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
