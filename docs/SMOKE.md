# Shell smoke checklist (REF-01)

Manual, non-hermetic checks after meaningful shell changes. Reference profile:

**REF-01** — English Windows XP Pro SP3 / Luna Blue / Welcome / default DPI.

Not run in CI yet (see GitHub #44). Print this list: `./scripts/smoke-notes.sh`.

## Checklist

- [ ] Shell starts (`quickshell`) without QML errors for the active theme
- [ ] Taskbar paints (Start button, plate, task buttons, tray, clock)
- [ ] Left-click Start opens popup above the button; Esc / click-away dismisses; right-click still opens Properties
- [ ] Start search filters apps; A–Z / Z–A and letter combo change the list; launching an app closes Start
- [ ] Start → “About QuickXP…” opens the themed message box
- [ ] Switch theme via Settings → Theme (or `Theme.name`) and confirm live reload
- [ ] Settings → Theme → Import… an XP `.msstyles` → one theme with schemes → Color scheme dropdown → Apply reloads chrome; Delete removes user-data themes only
- [ ] Post a freedesktop notification; tray / balloon / queue behaves as expected for the generation
- [ ] Run dialog (Epic R) — Win+R / Start → Run when implemented
- [ ] Shell hotkeys (Epic H) — Win, Win+R/E/D/L, etc. when implemented
- [ ] Match window borders / Aurorae: Apply with toggle on → KWin titlebar updates to `quickxp-<slug>`; toggle off → KWin unchanged; Theme Sample shows titlebar preview; Regenerate borders works for Luna
- [ ] Settings → Taskbar → Icons only: Apply → task buttons shrink to icons (no titles)
- [ ] Settings → Taskbar → Group similar (labels): many windows of one app combine only when the band is full; click group → title list
- [ ] Settings → Taskbar → Icon taskbar preset: always-combined icons; click group → thumbnail strip

Mark items N/A until the matching epic lands. Prefer a short note of failures over silent skips.
