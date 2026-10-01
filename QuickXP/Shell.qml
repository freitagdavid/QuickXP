import QtQuick
import Quickshell
import qs.QuickXP.taskbar

ShellRoot {
  property string theme: "luna"

  Component.onCompleted: Theme.name = theme
  onThemeChanged: Theme.name = theme

  TaskBar {}
}
