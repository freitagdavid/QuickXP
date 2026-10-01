# Shell smoke checklist (REF-01)

Manual, non-hermetic checks after meaningful shell changes. Reference profile:

**REF-01** — English Windows XP Pro SP3 / Luna Blue / Welcome / default DPI.

Not run in CI yet (see GitHub #44). Print this list: `./scripts/smoke-notes.sh`.

## Checklist

- [ ] Shell starts (`quickshell`) without QML errors for the active theme
- [ ] Taskbar paints (Start button, plate, task buttons, tray, clock)
- [ ] Open Start (when Start menu is available for the generation under test)
- [ ] Switch theme via Settings → Theme (or `Theme.name`) and confirm live reload
- [ ] Post a freedesktop notification; tray / balloon / queue behaves as expected for the generation
- [ ] Run dialog (Epic R) — Win+R / Start → Run when implemented
- [ ] Shell hotkeys (Epic H) — Win, Win+R/E/D/L, etc. when implemented
- [ ] Match window borders / Aurorae (Epic K) when “Match window borders” is on

Mark items N/A until the matching epic lands. Prefer a short note of failures over silent skips.
