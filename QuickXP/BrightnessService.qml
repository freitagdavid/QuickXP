pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property bool available: false
  property bool binaryPresent: false
  property real brightness: 0
  property int maxBrightness: 100
  property string device: ""

  readonly property real percent: maxBrightness > 0 ? brightness / maxBrightness : 0

  function refresh() {
    if (!root.binaryPresent)
      return
    probe.running = false
    probe.running = true
  }

  function setPercent(p) {
    if (!root.binaryPresent)
      return
    const v = Math.max(0, Math.min(1, Number(p) || 0))
    const pct = Math.round(v * 100)
    setProc.command = ["sh", "-c", "brightnessctl set " + pct + "%"]
    setProc.running = false
    setProc.running = true
  }

  function nudge(steps) {
    if (!root.binaryPresent)
      return
    const delta = (Number(steps) || 0) * 5
    const pct = Math.max(0, Math.min(100, Math.round(root.percent * 100) + delta))
    setProc.command = ["sh", "-c", "brightnessctl set " + pct + "%"]
    setProc.running = false
    setProc.running = true
  }

  // Detect binary via sh so a missing brightnessctl does not spam
  // "Process failed to start" for a non-existent argv0.
  Process {
    id: detect
    command: ["sh", "-c", "command -v brightnessctl"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.binaryPresent = String(text || "").trim() !== ""
        if (root.binaryPresent)
          root.refresh()
        else
          root.available = false
      }
    }
    onExited: (code) => {
      if (code !== 0) {
        root.binaryPresent = false
        root.available = false
      }
    }
  }

  Process {
    id: probe
    command: ["sh", "-c", "brightnessctl -m info"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const line = String(text || "").trim()
        const parts = line.split(",")
        if (parts.length < 5) {
          root.available = false
          return
        }
        root.device = parts[0]
        root.brightness = Number(parts[2]) || 0
        root.maxBrightness = Number(parts[4]) || 100
        root.available = root.maxBrightness > 0
      }
    }
    onExited: (code) => {
      if (code !== 0)
        root.available = false
    }
  }

  Process {
    id: setProc
    command: ["sh", "-c", "true"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Timer {
    interval: 4000
    running: root.available
    repeat: true
    onTriggered: root.refresh()
  }
}
