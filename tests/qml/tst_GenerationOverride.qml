import QtQuick
import QtTest
import "../../QuickXP/GenerationOverride.js" as GenerationOverride

TestCase {
  name: "GenerationOverride"

  function test_normalizeToggle() {
    compare(GenerationOverride.normalizeToggle("enabled"), "enabled")
    compare(GenerationOverride.normalizeToggle("on"), "enabled")
    compare(GenerationOverride.normalizeToggle("disabled"), "disabled")
    compare(GenerationOverride.normalizeToggle("off"), "disabled")
    compare(GenerationOverride.normalizeToggle("vista"), "enabled")
    compare(GenerationOverride.normalizeToggle("win7"), "enabled")
    compare(GenerationOverride.normalizeToggle("xp"), "disabled")
    compare(GenerationOverride.normalizeToggle(""), "")
  }

  function test_withFollowChoice() {
    const choices = GenerationOverride.withFollowChoice(
      [{ id: "xp", label: "Dual column (XP)" }],
      "Use shell default"
    )
    compare(choices.length, 2)
    compare(choices[0].id, "")
    compare(choices[0].label, "Use shell default")
    compare(choices[1].label, "Dual column (XP)")
  }
}
