import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import qs.QuickXP
import "TrayVolumeModel.js" as TrayVolumeModel

Item {
  id: root

  property var trayRoot: null
  property bool appsExpanded: true

  readonly property bool ready: Pipewire.ready && !!Pipewire.defaultAudioSink
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool win7Chrome: String(GenerationPolicy.shell || "") === "win7"
  // Only bind stream/link/source objects while the mixer is open. Keeping
  // PwNodeLinkTracker + per-app PwObjectTrackers alive always causes
  // quickshell "no global N any more" spam as short-lived PW nodes die.
  readonly property bool mixerOpen: mixer.visible
  implicitWidth: volIcon.width
  width: implicitWidth
  height: parent ? parent.height : 30

  readonly property var sinkList: {
    if (!root.mixerOpen)
      return []
    const model = Pipewire.nodes
    const out = []
    if (!model || !model.values)
      return out
    const values = model.values
    for (let i = 0; i < values.length; ++i) {
      const n = values[i]
      if (TrayVolumeModel.isAudioSinkNode(n))
        out.push(n)
    }
    return out
  }

  readonly property int appCount: {
    if (!root.mixerOpen)
      return 0
    const g = linkTracker.linkGroups
    if (!g || !g.values)
      return 0
    return g.values.length
  }

  // Tray icon only needs the default sink's mute/volume.
  PwObjectTracker {
    objects: root.sink ? [root.sink] : []
  }

  PwNodeLinkTracker {
    id: linkTracker
    node: root.mixerOpen ? Pipewire.defaultAudioSink : null
  }

  function iconName(): string {
    if (!root.sink || !root.sink.audio)
      return "audio-volume-high"
    return TrayVolumeModel.volumeIconName(root.sink.audio.muted, root.sink.audio.volume)
  }

  function tipTitle(): string {
    if (!root.sink || !root.sink.audio)
      return "Volume"
    if (root.sink.audio.muted)
      return "Muted"
    return "Volume: " + TrayVolumeModel.volumePercent(root.sink.audio.volume) + "%"
  }

  function tipBody(): string {
    return TrayVolumeModel.nodeLabel(root.sink)
  }

  function nudge(steps) {
    if (!root.sink || !root.sink.audio)
      return
    root.sink.audio.muted = false
    root.sink.audio.volume = TrayVolumeModel.adjustVolume(root.sink.audio.volume, steps)
  }

  function toggleMute() {
    if (!root.sink || !root.sink.audio)
      return
    root.sink.audio.muted = !root.sink.audio.muted
  }

  function setDefaultSink(node) {
    if (!node)
      return
    Pipewire.preferredDefaultAudioSink = node
  }

  function routeStream(streamNode, sinkNode) {
    if (!streamNode || !sinkNode)
      return
    const idx = TrayVolumeModel.pulseSinkInputIndex(streamNode)
    const sinkName = String(sinkNode.name || "")
    const argv = TrayVolumeModel.pactlMoveSinkInputCommand(idx, sinkName)
    if (argv.length)
      Quickshell.execDetached(argv)
  }

  function closePopup() {
    mixer.close()
  }

  function openPopup() {
    mixer.openAt(volIcon)
  }

  TrayControlIcon {
    id: volIcon
    trayRoot: root.trayRoot
    active: Config.options.trayShowVolume && root.ready
    iconSource: "image://icon/" + root.iconName()
    tipTitle: root.tipTitle()
    tipBody: root.tipBody()
    onActivated: {
      if (root.trayRoot && typeof root.trayRoot.closeTrayPopups === "function")
        root.trayRoot.closeTrayPopups(mixer)
      mixer.openAt(volIcon)
    }
    onMiddleActivated: root.toggleMute()
    onWheelDelta: (steps) => root.nudge(steps)
  }

  TrayPopup {
    id: mixer
    anchorItem: volIcon
    heading: root.win7Chrome ? "Volume Mixer" : "Volume"
    contentWidth: 300
    // Natural height of sections; TrayPopup caps and scrolls when taller.
    contentHeight: 72
      + 52
      + 18
      + Math.max(18, root.sinkList.length * 18)
      + 8
      + 20
      + (root.appsExpanded ? Math.max(18, root.appCount * 52) : 0)
      + (root.source ? 60 : 0)
    maxContentHeight: 360

    Text {
      width: parent.width
      text: "Speakers"
      font.bold: true
      font.pixelSize: 11
      font.family: Theme.value("fonts", "ui", "Tahoma")
      color: Theme.color("menuText", "#000000")
    }

    MixerEntry {
      width: parent.width
      node: root.sink
      trackNode: root.mixerOpen
      showRoute: false
    }

    Text {
      width: parent.width
      text: "Output device"
      font.pixelSize: 10
      font.family: Theme.value("fonts", "ui", "Tahoma")
      color: Theme.color("menuText", "#000000")
    }

    Column {
      width: parent.width
      spacing: 2
      Repeater {
        model: root.sinkList
        delegate: Text {
          required property var modelData
          width: parent.width
          height: 18
          text: (Pipewire.defaultAudioSink === modelData ? "● " : "  ") + TrayVolumeModel.nodeLabel(modelData)
          font.pixelSize: 11
          font.family: Theme.value("fonts", "ui", "Tahoma")
          color: Theme.color("menuText", "#000000")
          MouseArea {
            anchors.fill: parent
            onClicked: root.setDefaultSink(modelData)
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.color("border", "#003C74")
    }

    Text {
      width: parent.width
      text: (root.appsExpanded ? "▼ " : "▶ ") + "Applications"
      font.pixelSize: 11
      font.bold: true
      font.family: Theme.value("fonts", "ui", "Tahoma")
      color: Theme.color("menuText", "#000000")
      MouseArea {
        anchors.fill: parent
        onClicked: root.appsExpanded = !root.appsExpanded
      }
    }

    Column {
      visible: root.appsExpanded
      width: parent.width
      spacing: 4

      Repeater {
        model: linkTracker.linkGroups
        delegate: MixerEntry {
          required property var modelData
          width: parent.width
          node: modelData.source
          showRoute: true
          sinkNodes: root.sinkList
          onRouteRequested: (sinkNode) => root.routeStream(node, sinkNode)
        }
      }

      Text {
        visible: root.appCount === 0
        text: "No application sounds"
        font.pixelSize: 10
        font.family: Theme.value("fonts", "ui", "Tahoma")
        color: "#666666"
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.color("border", "#003C74")
      visible: !!root.source
    }

    Text {
      visible: !!root.source
      width: parent.width
      text: "Microphone"
      font.bold: true
      font.pixelSize: 11
      font.family: Theme.value("fonts", "ui", "Tahoma")
      color: Theme.color("menuText", "#000000")
    }

    MixerEntry {
      visible: !!root.source
      width: parent.width
      node: root.source
      trackNode: root.mixerOpen
      showRoute: false
    }
  }
}
