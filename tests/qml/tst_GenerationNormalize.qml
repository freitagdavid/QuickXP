import QtQuick
import QtTest
import "../../QuickXP/GenerationNormalize.js" as GenerationNormalize

TestCase {
  name: "GenerationNormalize"

  function test_passthrough() {
    compare(GenerationNormalize.normalize("xp", "vista"), "xp")
    compare(GenerationNormalize.normalize("vista", "xp"), "vista")
    compare(GenerationNormalize.normalize("win7", "xp"), "win7")
    compare(GenerationNormalize.normalize("classic", "xp"), "classic")
  }

  function test_aliases() {
    compare(GenerationNormalize.normalize("Windows XP", "vista"), "xp")
    compare(GenerationNormalize.normalize("winxp", "vista"), "xp")
    compare(GenerationNormalize.normalize("Windows Vista", "xp"), "vista")
    compare(GenerationNormalize.normalize("windows7", "xp"), "win7")
    compare(GenerationNormalize.normalize("win 7", "xp"), "win7")
    compare(GenerationNormalize.normalize("Windows Classic", "xp"), "classic")
  }

  function test_fallback() {
    compare(GenerationNormalize.normalize("unknown", "vista"), "vista")
    compare(GenerationNormalize.normalize("", "win7"), "win7")
    compare(GenerationNormalize.normalize(null, "classic"), "classic")
    compare(GenerationNormalize.normalize("nope"), "xp")
  }
}
