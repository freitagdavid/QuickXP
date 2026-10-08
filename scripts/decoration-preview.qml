import QtQuick

Window {
    id: window
    visible: true
    width: 720
    height: 420
    title: "QuickXP decoration preview"
    color: "#efece7"

    Text {
        anchors.centerIn: parent
        width: parent.width - 48
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: "#1a1a1a"
        text: "Nested KWin preview. Saving decoration QML restarts this window."
    }
}
