import QtQuick
import Quickshell

ShellRoot {
  property string theme: "luna"

  Component.onCompleted: Theme.name = theme
  onThemeChanged: Theme.name = theme

  TaskBar {}
}
