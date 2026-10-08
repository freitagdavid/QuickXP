import QtQuick
import QtTest
import "../../QuickXP/TasksModel.js" as TasksModel

TestCase {
  name: "TasksModel"

  function test_parseWindowsJson_empty_and_invalid() {
    compare(TasksModel.parseWindowsJson(""), [])
    compare(TasksModel.parseWindowsJson("   "), [])
    compare(TasksModel.parseWindowsJson(null), [])
    compare(TasksModel.parseWindowsJson("{"), [])
    compare(TasksModel.parseWindowsJson("{}"), [])
  }

  function test_parseWindowsJson_valid() {
    const rows = TasksModel.parseWindowsJson('[{"id":"1","title":"A"}]')
    compare(rows.length, 1)
    compare(rows[0].id, "1")
    compare(rows[0].title, "A")
  }

  function test_formatCommandLine() {
    compare(TasksModel.formatCommandLine("{abc}", "activate"), "COMMAND {abc} activate\n")
    compare(TasksModel.formatCommandLine("", "activate"), "")
    compare(TasksModel.formatCommandLine("{abc}", ""), "")
  }

  function test_formatPreviewRequest() {
    compare(TasksModel.formatPreviewRequest(12, "{abc}"), "PREVIEW 12 {abc}\n")
    compare(TasksModel.formatPreviewRequest(1, ""), "")
  }

  function test_formatShowDesktop() {
    compare(TasksModel.formatShowDesktop(), "SHOWDESKTOP\n")
  }

  function test_useKwinSession() {
    compare(TasksModel.useKwinSession("KDE", ""), true)
    compare(TasksModel.useKwinSession("ubuntu:KDE", ""), true)
    compare(TasksModel.useKwinSession("QuickXP", ""), true)
    compare(TasksModel.useKwinSession("quickxp", ""), true)
    compare(TasksModel.useKwinSession("Hyprland", "true"), true)
    compare(TasksModel.useKwinSession("Hyprland", ""), false)
    compare(TasksModel.useKwinSession("", ""), false)
  }

  function test_parsePreviewReply() {
    const hit = TasksModel.parsePreviewReply("PREVIEW 3 /tmp/x.png")
    compare(hit.serial, 3)
    compare(hit.path, "/tmp/x.png")
    const miss = TasksModel.parsePreviewReply("PREVIEW 3 -")
    compare(miss.serial, 3)
    compare(miss.path, "")
    compare(TasksModel.parsePreviewReply("NOPE"), null)
    compare(TasksModel.parsePreviewReply(""), null)
  }
}
