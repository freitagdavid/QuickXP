import QtQuick
import QtTest
import "../../QuickXP/tray/TrayVolumeModel.js" as TrayVolumeModel

TestCase {
  name: "TrayVolumeModel"

  function test_clamp_and_adjust() {
    compare(TrayVolumeModel.clampVolume(-1), 0)
    compare(TrayVolumeModel.clampVolume(2), 1)
    compare(TrayVolumeModel.adjustVolume(0.5, 1), 0.55)
    compare(TrayVolumeModel.adjustVolume(0.02, -1), 0)
  }

  function test_volume_icon_name() {
    compare(TrayVolumeModel.volumeIconName(true, 0.8), "audio-volume-muted")
    compare(TrayVolumeModel.volumeIconName(false, 0), "audio-volume-muted")
    compare(TrayVolumeModel.volumeIconName(false, 0.2), "audio-volume-low")
    compare(TrayVolumeModel.volumeIconName(false, 0.5), "audio-volume-medium")
    compare(TrayVolumeModel.volumeIconName(false, 0.9), "audio-volume-high")
  }

  function test_stream_label_and_pactl() {
    const node = {
      description: "Firefox",
      properties: { "application.name": "Firefox", "media.name": "YouTube" }
    }
    compare(TrayVolumeModel.streamLabel(node), "Firefox — YouTube")
    const cmd = TrayVolumeModel.pactlMoveSinkInputCommand("12", "alsa_output.pci")
    compare(cmd.length, 4)
    compare(cmd[0], "pactl")
    compare(cmd[2], "12")
  }

  function test_is_audio_sink_node() {
    verify(TrayVolumeModel.isAudioSinkNode({ isSink: true, isStream: false }))
    verify(!TrayVolumeModel.isAudioSinkNode({ isSink: true, isStream: true }))
    verify(!TrayVolumeModel.isAudioSinkNode(null))
  }
}
