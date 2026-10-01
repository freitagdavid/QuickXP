pragma Singleton

import QtQuick
import Quickshell
import "GenerationNormalize.js" as GenerationNormalize
import "GenerationOverride.js" as GenerationOverride

// Resolves shell generation (classic / xp / vista / win7) for layout and fidelity.
// Shell default follows Theme.generation unless Config.options.generation is set.
// Each policy item may override that shell default via Config.options.generationOverrides.
Singleton {
  id: root

  readonly property var generations: ["classic", "xp", "vista", "win7"]

  // Stable keys for features that diverge by generation. Empty override = use shell.
  // kind "choice": mutually exclusive layouts (descriptive labels, generation ids).
  // kind "toggle": enable/disable features (values "", "enabled", "disabled").
  readonly property var items: [
    {
      id: "startMenu",
      label: "Start menu layout",
      kind: "choice",
      hint: "Column layout of the Start menu",
      choices: [
        { id: "classic", label: "Single column (Classic)" },
        { id: "xp", label: "Dual column (XP)" },
        { id: "vista", label: "Search Start (Vista)" },
        { id: "win7", label: "Search Start (Windows 7)" }
      ]
    },
    {
      id: "startSearch",
      label: "Start menu search",
      kind: "toggle",
      hint: "Search box in the Start menu",
      defaultOnGenerations: ["vista", "win7"]
    },
    {
      id: "quickLaunch",
      label: "Quick Launch",
      kind: "choice",
      hint: "Quick Launch toolbar placement",
      choices: [
        { id: "classic", label: "Classic Quick Launch bar" },
        { id: "xp", label: "XP Quick Launch (left of tasks)" },
        { id: "vista", label: "Vista Quick Launch" },
        { id: "win7", label: "Pinned apps (Windows 7 style)" }
      ]
    },
    {
      id: "taskbarGrouping",
      label: "Taskbar grouping",
      kind: "choice",
      hint: "When task buttons combine",
      choices: [
        { id: "classic", label: "Never combine" },
        { id: "xp", label: "Combine when taskbar is full (XP)" },
        { id: "vista", label: "Combine when full (Vista)" },
        { id: "win7", label: "Always combine (Windows 7)" }
      ]
    },
    {
      id: "showDesktop",
      label: "Show Desktop",
      kind: "choice",
      hint: "Where Show Desktop lives",
      choices: [
        { id: "classic", label: "Quick Launch icon" },
        { id: "xp", label: "Quick Launch icon (XP)" },
        { id: "vista", label: "Quick Launch icon (Vista)" },
        { id: "win7", label: "Tray-edge peek button (Windows 7)" }
      ]
    },
    {
      id: "livePeeks",
      label: "Taskbar live peeks",
      kind: "toggle",
      hint: "Thumbnail peeks on taskbar hover",
      defaultOnGenerations: ["vista", "win7"]
    },
    {
      id: "notificationRetention",
      label: "Notification retention",
      kind: "choice",
      hint: "How tray notifications stick around",
      choices: [
        { id: "classic", label: "Balloons only" },
        { id: "xp", label: "Balloons only (XP)" },
        { id: "vista", label: "Tray notification queue (Vista)" },
        { id: "win7", label: "Tray notification queue (Windows 7)" }
      ]
    },
    {
      id: "winTab",
      label: "Win+Tab",
      kind: "choice",
      hint: "What Win+Tab does",
      choices: [
        { id: "classic", label: "Cycle taskbar buttons" },
        { id: "xp", label: "Cycle taskbar buttons (XP)" },
        { id: "vista", label: "Flip 3D / overview (Vista)" },
        { id: "win7", label: "Aero Peek overview (Windows 7)" }
      ]
    },
    {
      id: "clockFlyout",
      label: "Clock double-click",
      kind: "choice",
      hint: "Clock / date UI",
      choices: [
        { id: "classic", label: "Date and Time Properties" },
        { id: "xp", label: "Date and Time Properties (XP)" },
        { id: "vista", label: "Calendar flyout (Vista)" },
        { id: "win7", label: "Calendar flyout (Windows 7)" }
      ]
    },
    {
      id: "altTabOverview",
      label: "Alt+Tab / overview",
      kind: "choice",
      hint: "Task switcher chrome",
      choices: [
        { id: "classic", label: "Compact list switcher" },
        { id: "xp", label: "Compact list switcher (XP)" },
        { id: "vista", label: "Thumbnail switcher (Vista)" },
        { id: "win7", label: "Thumbnail switcher (Windows 7)" }
      ]
    }
  ]

  readonly property var generationLabels: ({
    "": "Follow theme",
    "classic": "Windows Classic",
    "xp": "Windows XP",
    "vista": "Windows Vista",
    "win7": "Windows 7"
  })

  readonly property var toggleChoices: [
    { id: "enabled", label: "Enabled" },
    { id: "disabled", label: "Disabled" }
  ]

  readonly property string themeGeneration: normalize(Theme.generation, "xp")

  // Explicit shell generation when Config.options.generation is set; otherwise theme.
  readonly property string shell: {
    const configured = Config.options.generation
    if (configured !== undefined && configured !== null && String(configured).trim() !== "")
      return normalize(configured, themeGeneration)
    return themeGeneration
  }

  function normalize(value, fallback): string {
    return GenerationNormalize.normalize(value, fallback)
  }

  function labelFor(generation: string, followLabel: string): string {
    const key = generation === undefined || generation === null ? "" : String(generation)
    if (key === "")
      return followLabel !== undefined ? followLabel : generationLabels[""]
    const named = generationLabels[normalize(key, key)]
    return named !== undefined ? named : key
  }

  function itemMeta(itemId: string): var {
    const list = items
    for (let i = 0; i < list.length; ++i) {
      if (list[i].id === itemId)
        return list[i]
    }
    return undefined
  }

  function isToggle(itemId: string): bool {
    const meta = itemMeta(itemId)
    return meta !== undefined && meta.kind === "toggle"
  }

  function choicesFor(itemId: string, followLabel: string): var {
    const meta = itemMeta(itemId)
    if (meta === undefined) {
      return GenerationOverride.withFollowChoice([
        { id: "classic", label: "Windows Classic" },
        { id: "xp", label: "Windows XP" },
        { id: "vista", label: "Windows Vista" },
        { id: "win7", label: "Windows 7" }
      ], followLabel)
    }
    if (meta.kind === "toggle")
      return GenerationOverride.withFollowChoice(toggleChoices, followLabel)
    return GenerationOverride.withFollowChoice(meta.choices, followLabel)
  }

  function overrideFor(itemId: string): string {
    const bag = Config.options.generationOverrides
    if (bag === undefined || bag === null)
      return ""
    const value = bag[itemId]
    if (value === undefined || value === null)
      return ""
    return String(value).trim()
  }

  function normalizeOverride(itemId: string, value): string {
    if (value === undefined || value === null)
      return ""
    const raw = String(value).trim()
    if (raw === "")
      return ""
    if (isToggle(itemId)) {
      const meta = itemMeta(itemId)
      const onGens = meta && meta.defaultOnGenerations ? meta.defaultOnGenerations : ["vista", "win7"]
      const toggled = GenerationOverride.normalizeToggle(raw, onGens)
      if (toggled !== "")
        return toggled
      // Unknown token — try generation alias then toggle mapping.
      return GenerationOverride.normalizeToggle(normalize(raw, ""), onGens)
    }
    return normalize(raw, "")
  }

  function defaultFeatureOn(itemId: string): bool {
    const meta = itemMeta(itemId)
    const onGens = meta && meta.defaultOnGenerations ? meta.defaultOnGenerations : ["vista", "win7"]
    const g = shell
    for (let i = 0; i < onGens.length; ++i) {
      if (onGens[i] === g)
        return true
    }
    return false
  }

  // Effective on/off for toggle policy items.
  function featureEnabled(itemId: string): bool {
    const override = normalizeOverride(itemId, overrideFor(itemId))
    if (override === "enabled")
      return true
    if (override === "disabled")
      return false
    return defaultFeatureOn(itemId)
  }

  // Effective generation for a policy item. Prefer this over Theme.generation.
  // Toggle items map enabled→vista-class, disabled→xp-class for existing consumers.
  function forItem(itemId: string): string {
    if (isToggle(itemId)) {
      if (featureEnabled(itemId)) {
        const g = shell
        if (g === "vista" || g === "win7")
          return g
        return "vista"
      }
      const g = shell
      if (g === "classic" || g === "xp")
        return g
      return "xp"
    }
    const override = normalizeOverride(itemId, overrideFor(itemId))
    if (override !== "")
      return override
    return shell
  }

  function is(itemId: string, generation: string): bool {
    return forItem(itemId) === normalize(generation, "")
  }

  function isClassic(itemId: string): bool {
    return forItem(itemId) === "classic"
  }

  function isXp(itemId: string): bool {
    return forItem(itemId) === "xp"
  }

  function isVistaOrLater(itemId: string): bool {
    const g = forItem(itemId)
    return g === "vista" || g === "win7"
  }

  function emptyOverrides(): var {
    const out = {}
    const list = items
    for (let i = 0; i < list.length; ++i)
      out[list[i].id] = ""
    return out
  }

  function copyOverrides(source): var {
    const out = emptyOverrides()
    if (source === undefined || source === null)
      return out
    for (const key in out) {
      const value = source[key]
      if (value !== undefined && value !== null && String(value).trim() !== "")
        out[key] = normalizeOverride(key, value)
    }
    return out
  }

  function overridesEqual(a, b): bool {
    const left = copyOverrides(a)
    const right = copyOverrides(b)
    for (const key in left) {
      if (left[key] !== right[key])
        return false
    }
    return true
  }

  function applyOverridesToConfig(source) {
    const bag = Config.options.generationOverrides
    const copied = copyOverrides(source)
    for (const key in copied)
      bag[key] = copied[key]
  }
}
