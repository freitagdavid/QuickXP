import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.QuickXP

Item {
  id: root

  property var trayRoot: null

  implicitWidth: row.implicitWidth
  implicitHeight: parent ? parent.height : 30
  height: implicitHeight

  function closeAllPopups(except) {
    if (volume && typeof volume.closePopup === "function" && volume !== except)
      volume.closePopup()
    const pops = [netPopup, btPopup, brightPopup, batPopup, drivePopup]
    for (let i = 0; i < pops.length; ++i) {
      if (pops[i] && pops[i] !== except)
        pops[i].close()
    }
  }

  function openExclusive(popup, item) {
    closeAllPopups(popup)
    if (trayRoot && typeof trayRoot.hideTip === "function")
      trayRoot.hideTip(null)
    popup.openAt(item)
  }

  Row {
    id: row
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    spacing: 2

    VolumeMixer {
      id: volume
      trayRoot: root.trayRoot
      height: parent.height
    }

    // --- Network ---
    TrayControlIcon {
      id: netIcon
      trayRoot: root.trayRoot
      readonly property bool netUp: Networking.connectivity === NetworkConnectivity.Full
        || Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal
      active: Config.options.trayShowNetwork && Networking.backend === NetworkBackendType.NetworkManager
      iconSource: netUp ? "image://icon/network-wired" : "image://icon/network-offline"
      tipTitle: netUp ? "Connected" : "Network"
      tipBody: netUp ? "Click for networks" : "Disconnected"
      onActivated: root.openExclusive(netPopup, netIcon)
    }

    TrayPopup {
      id: netPopup
      anchorItem: netIcon
      heading: "Network"
      contentWidth: 260
      contentHeight: 280
      maxContentHeight: 320

      Text {
        width: parent.width
        text: Networking.wifiEnabled ? "Wi‑Fi on" : "Wi‑Fi off"
        font.pixelSize: 11
        font.family: Theme.value("fonts", "ui", "Tahoma")
        MouseArea {
          anchors.fill: parent
          onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
        }
      }

      Column {
        width: parent.width
        spacing: 2

        Repeater {
          model: Networking.devices
          delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 2

            Text {
              text: String(modelData.name || "Device")
              font.bold: true
              font.pixelSize: 10
              font.family: Theme.value("fonts", "ui", "Tahoma")
            }

            Repeater {
              model: modelData.networks
              delegate: Text {
                required property var modelData
                width: parent.width
                height: 18
                text: (modelData.connected ? "● " : "  ") + String(modelData.name || "Network")
                font.pixelSize: 11
                font.family: Theme.value("fonts", "ui", "Tahoma")
                elide: Text.ElideRight
                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    if (modelData.connected)
                      modelData.disconnect()
                    else
                      modelData.connect()
                  }
                }
              }
            }
          }
        }
      }
    }

    // --- Bluetooth ---
    TrayControlIcon {
      id: btIcon
      trayRoot: root.trayRoot
      active: Config.options.trayShowBluetooth && !!Bluetooth.defaultAdapter
      iconSource: {
        const ad = Bluetooth.defaultAdapter
        if (!ad || !ad.enabled)
          return "image://icon/bluetooth-disabled"
        return "image://icon/bluetooth-active"
      }
      tipTitle: "Bluetooth"
      tipBody: {
        const ad = Bluetooth.defaultAdapter
        if (!ad)
          return ""
        return ad.enabled ? "On" : "Off"
      }
      onActivated: root.openExclusive(btPopup, btIcon)
    }

    TrayPopup {
      id: btPopup
      anchorItem: btIcon
      heading: "Bluetooth"
      contentWidth: 240
      contentHeight: 240
      maxContentHeight: 320

      Text {
        width: parent.width
        text: {
          const ad = Bluetooth.defaultAdapter
          return ad && ad.enabled ? "Turn off adapter" : "Turn on adapter"
        }
        font.pixelSize: 11
        font.family: Theme.value("fonts", "ui", "Tahoma")
        MouseArea {
          anchors.fill: parent
          onClicked: {
            const ad = Bluetooth.defaultAdapter
            if (ad)
              ad.enabled = !ad.enabled
          }
        }
      }

      Column {
        width: parent.width
        spacing: 2
        Repeater {
          model: Bluetooth.devices
          delegate: Text {
            required property var modelData
            width: parent.width
            height: 18
            text: (modelData.connected ? "● " : "  ") + String(modelData.name || modelData.deviceId || "Device")
            font.pixelSize: 11
            font.family: Theme.value("fonts", "ui", "Tahoma")
            elide: Text.ElideRight
            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (modelData.connected)
                  modelData.disconnect()
                else
                  modelData.connect()
              }
            }
          }
        }
      }
    }

    // --- Brightness ---
    TrayControlIcon {
      id: brightIcon
      trayRoot: root.trayRoot
      active: Config.options.trayShowBrightness && BrightnessService.available
      iconSource: "image://icon/display-brightness"
      tipTitle: "Brightness"
      tipBody: Math.round(BrightnessService.percent * 100) + "%"
      onActivated: root.openExclusive(brightPopup, brightIcon)
      onWheelDelta: (steps) => BrightnessService.nudge(steps)
    }

    TrayPopup {
      id: brightPopup
      anchorItem: brightIcon
      heading: "Brightness"
      contentWidth: 220
      contentHeight: 70

      Slider {
        width: parent.width
        from: 0
        to: 1
        value: BrightnessService.percent
        onMoved: BrightnessService.setPercent(value)
      }

      Text {
        text: Math.round(BrightnessService.percent * 100) + "%"
        font.pixelSize: 11
        font.family: Theme.value("fonts", "ui", "Tahoma")
      }
    }

    // --- Battery ---
    TrayControlIcon {
      id: batIcon
      trayRoot: root.trayRoot
      readonly property var device: UPower.displayDevice
      readonly property bool showBat: {
        const d = device
        if (!d)
          return false
        return d.isLaptopBattery || UPower.onBattery
      }
      active: Config.options.trayShowBattery && showBat
      iconSource: {
        const d = device
        if (!d)
          return "image://icon/battery"
        const name = d.iconName
        if (name && String(name).trim() !== "")
          return "image://icon/" + String(name)
        return "image://icon/battery"
      }
      tipTitle: "Battery"
      tipBody: {
        const d = device
        if (!d)
          return ""
        const pct = Math.round(Number(d.percentage) || 0)
        return pct + "%"
      }
      onActivated: root.openExclusive(batPopup, batIcon)
    }

    TrayPopup {
      id: batPopup
      anchorItem: batIcon
      heading: "Power"
      contentWidth: 180
      contentHeight: 60

      Text {
        width: parent.width
        text: {
          const d = UPower.displayDevice
          if (!d)
            return "No battery"
          return Math.round(Number(d.percentage) || 0) + "% — " + String(d.state || "")
        }
        font.pixelSize: 11
        font.family: Theme.value("fonts", "ui", "Tahoma")
        wrapMode: Text.WordWrap
      }
    }

    // --- Removable drives ---
    TrayControlIcon {
      id: driveIcon
      trayRoot: root.trayRoot
      active: Config.options.trayShowDrives && DrivesService.hasDrives
      iconSource: "image://icon/drive-removable-media"
      tipTitle: "Removable drives"
      tipBody: DrivesService.drives.length + " device(s)"
      onActivated: root.openExclusive(drivePopup, driveIcon)
    }

    TrayPopup {
      id: drivePopup
      anchorItem: driveIcon
      heading: "Safely Remove Hardware"
      contentWidth: 260
      contentHeight: Math.min(220, 40 + DrivesService.drives.length * 36)

      Column {
        width: parent.width
        spacing: 4
        Repeater {
          model: DrivesService.drives
          delegate: Row {
            required property var modelData
            width: parent.width
            height: 32
            spacing: 8

            Text {
              width: parent.width - 100
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              text: String(modelData.label || modelData.name || "Drive")
              font.pixelSize: 11
              font.family: Theme.value("fonts", "ui", "Tahoma")
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Open"
              font.pixelSize: 10
              font.underline: true
              color: "#003399"
              visible: !!(modelData.mountpoint)
              MouseArea {
                anchors.fill: parent
                onClicked: DrivesService.openMount(modelData.mountpoint)
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Eject"
              font.pixelSize: 10
              font.underline: true
              color: "#003399"
              MouseArea {
                anchors.fill: parent
                onClicked: DrivesService.eject(modelData.path || modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
