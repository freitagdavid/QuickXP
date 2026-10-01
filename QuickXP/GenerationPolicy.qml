pragma Singleton

import QtQuick
import Quickshell
import "GenerationNormalize.js" as GenerationNormalize

// Resolves shell generation (classic / xp / vista / win7) for layout and fidelity.
// Shell default follows Theme.generation unless Config.options.generation is set.
// Each policy item may override that shell default via Config.options.generationOverrides.
Singleton {
  id: root

  readonly property var generations: ["classic", "xp", "vista", "win7"]

  // Stable keys for features that diverge by generation. Empty override = use shell.
  readonly property var items: [
    {
      id: "startMenu",
      label: "Start menu layout",
      hint: "Classic single-column, XP dual-column, or Vista/7 search Start"
    },
    {
      id: "quickLaunch",
      label: "Quick Launch",
      hint: "Placement and visibility (Win7 may favor the tray-edge Show Desktop)"
    },
    {
      id: "taskbarGrouping",
      label: "Taskbar grouping",
      hint: "Crowding-triggered (XP) vs always-combined buttons"
    },
    {
      id: "showDesktop",
      label: "Show Desktop",
      hint: "Quick Launch icon vs Win7 far-right tray-edge button"
    },
    {
      id: "livePeeks",
      label: "Taskbar live peeks",
      hint: "XP title menus vs Vista/7 thumbnail strips"
    },
    {
      id: "notificationRetention",
      label: "Notification retention",
      hint: "XP balloons only vs persistent tray queue"
    },
    {
      id: "winTab",
      label: "Win+Tab",
      hint: "XP taskbar focus cycle vs modern overview"
    },
    {
      id: "clockFlyout",
      label: "Clock double-click",
      hint: "Date and Time Properties vs Vista/7 calendar flyout"
    },
    {
      id: "altTabOverview",
      label: "Alt+Tab / overview",
      hint: "Compact switcher vs optional full overview chrome"
    }
  ]

  readonly property var generationLabels: ({
    "": "Follow theme",
    "classic": "Windows Classic",
    "xp": "Windows XP",
    "vista": "Windows Vista",
    "win7": "Windows 7"
  })

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

  function overrideFor(itemId: string): string {
    const bag = Config.options.generationOverrides
    if (bag === undefined || bag === null)
      return ""
    const value = bag[itemId]
    if (value === undefined || value === null)
      return ""
    return String(value).trim()
  }

  // Effective generation for a policy item. Prefer this over Theme.generation.
  function forItem(itemId: string): string {
    const override = overrideFor(itemId)
    if (override !== "")
      return normalize(override, shell)
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

  function itemMeta(itemId: string): var {
    const list = items
    for (let i = 0; i < list.length; ++i) {
      if (list[i].id === itemId)
        return list[i]
    }
    return undefined
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
        out[key] = normalize(value, "")
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
