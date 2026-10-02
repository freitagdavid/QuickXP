# Shell smoke checklist (REF-01)

Manual, non-hermetic checks after meaningful shell changes. Reference profile:

**REF-01** — English Windows XP Pro SP3 / Luna Blue / Welcome / default DPI.

Not run in CI yet (see GitHub #44). Print this list: `./scripts/smoke-notes.sh`.

## Checklist

- [ ] Shell starts (`quickshell`) without QML errors for the active theme
- [ ] Taskbar paints (Start button, plate, task buttons, tray, clock)
- [ ] Left-click Start opens the active Start layout above the button (XP dual-column by default on Luna; Classic when `startMenu` override is classic); Esc / click-away dismisses; right-click still opens Properties
- [ ] Settings → Theme → Start menu layout: Dual column (XP) vs Single column (Classic) switches popup chrome without restart
- [ ] Classic Start: black→blue banner with distro name; beveled gray face; ~18px rows; no search box
- [ ] Classic Start flyouts: first level bottom-anchored, nested levels alternate; only one open per level; reopen after close works
- [ ] Start button flush to taskbar bottom with a tiny top drag-bar inset
- [ ] Classic Start: Documents/Settings/Search open submenus; Help/Run stubs; Log Off / Turn Off Computer confirm (Cancel safe)
- [ ] Settings → Start Menu: Programs source, MFU count, Clear List, place visibility cycle, highlight-new, personalized menus; Clear highlight / Clear recent
- [ ] Settings → Start Menu still toggles Programs source after session rows land
- [ ] XP Start: dual-column Luna chrome (user bar + tile/name, white left / places right); tile click opens User Accounts stub; `~/.face` shows when present
- [ ] XP Start right column: special folders open (docs/pictures/music/computer); Recent Documents / Admin Tools show flyout chevrons
- [ ] Settings → Debugging → Keep Start menu open: Apply keeps Start visible across reload / click-away
- [ ] XP Start footer: Log Off / Turn Off Computer confirm (Cancel safe); Luna icon strip
- [ ] XP Start right column: Help / Search / Run stubs at bottom (not a Vista search box)
- [ ] Vista/7 Start search (`generation` vista/win7 or `startSearch` enabled): search field in the left column, directly under All Programs, focuses on open; typing filters that column (Programs / Documents / Settings); right column stays beside it; menu stays open
- [ ] Vista/7 Start search keyboard: Down/Up highlight results; Enter launches; Esc clears query then closes
- [ ] XP Start All Programs: flyout from left footer with Programs tree; nested cascades align; reopen works
- [ ] XP Start pins: defaults seed browser/mail; launch works; right-click unpins; drag reorders
- [ ] XP Start MFU: launches populate list below pins; right-click removes from list without unpinning
- [ ] Switch theme via Settings → Theme (or `Theme.name`) and confirm live reload
- [ ] Settings → Theme → Import… an XP `.msstyles` → one theme with schemes → Color scheme dropdown → Apply reloads chrome; Delete removes user-data themes only
- [ ] Post a freedesktop notification; tray / balloon / queue behaves as expected for the generation
- [ ] Run dialog (Epic R) — Win+R / Start → Run when implemented
- [ ] Shell hotkeys (Epic H) — Win, Win+R/E/D/L, etc. when implemented
- [ ] Match window borders / Aurorae: Apply with toggle on → KWin titlebar updates to `quickxp-<slug>`; toggle off → KWin unchanged; Theme Sample shows titlebar preview; Regenerate borders works for Luna
- [ ] Settings → Taskbar → Icons only: Apply → task buttons shrink to icons (no titles)
- [ ] Settings → Taskbar → Group similar (labels): many windows of one app combine only when the band is full; click group → title list
- [ ] Settings → Taskbar → Icon taskbar preset: always-combined icons; click group → thumbnail strip
- [ ] Taskband stability: switch focus or let a browser change its title — task buttons should not flicker or reload chrome; labels/focus frame update in place
- [ ] Taskband clicks: activate / minimize / close still work (one-shot KWin apply; no idle 200 ms `TakeCommands` poll)

Mark items N/A until the matching epic lands. Prefer a short note of failures over silent skips.
