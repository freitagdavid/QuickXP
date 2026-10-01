# QuickXP

A [Quickshell](https://quickshell.org/) desktop shell inspired by Windows XP, with room to grow toward Vista and Windows 7. The goal is an XP-like taskbar and shell that can also pick up later-era features (window peek, icon-only taskbar, Win7-style volume mixer, and so on).

Today the project is a Luna-themed taskbar with a classic single-column Start menu (Programs cascade), task buttons, paging, system menus, tray, clock, and KWin window peeks. Dual-column XP Start and most of the rest of the shell are still on the roadmap — see [docs/ROADMAP.md](docs/ROADMAP.md).

## Requirements

- [Quickshell](https://quickshell.org/)
- Qt 6
- On KDE / Plasma: KWin (window list + peeks go through a small KWin script and D-Bus bridge)
- Python 3 with `dbus-python` and PyGObject (for `TasksBridge.py` on KDE)
- Optional: `pyxdg` for fuller XDG `applications.menu` parsing in Classic Start (falls back to a stdlib XML path / category folders)
- Optional theme tooling: Python 3 only (stdlib)

Window peeks also need the `quickxp-preview` helper (see below).

## Quick start

```sh
git clone https://github.com/freitagdavid/QuickXP.git
cd QuickXP
./scripts/setup.sh
quickshell
```

`scripts/setup.sh` checks for Quickshell / Python D-Bus deps, builds the KWin peek helper, and runs [`deploy.sh`](deploy.sh) (symlink the `QuickXP/` module into `~/.config/quickshell/default`). On Plasma, hide or disable the stock panel so it does not cover the QuickXP taskbar.

Rebuild only the peek helper:

```sh
./scripts/build-preview.sh
```

Deploy without rebuilding:

```sh
./deploy.sh
```

The active theme defaults to Luna (`theme: "luna"` in [`QuickXP/Shell.qml`](QuickXP/Shell.qml)). Themes live under [`QuickXP/themes/`](QuickXP/themes/) as `theme.json` plus image assets.

## What works now

- Bottom taskbar with Luna sprites (Start button, plate, task buttons, tray, pager arrows)
- Task list from KWin (KDE) or foreign toplevels elsewhere
- Activate / minimize, right-click system menu, crowding pager
- Hover window peek on KDE (falls back to title tooltip otherwise)
- System tray (StatusNotifier) with hide-inactive chevron and clock
- Live-reloading themes via [`QuickXP/Theme.qml`](QuickXP/Theme.qml)

## Theme tooling

Extract bitmaps and settings from a Windows XP `.msstyles` / `Shellstyle.dll` tree:

```sh
python3 scripts/extract_xp_theme.py /path/to/theme -o /path/to/out
```

Convert extracted BMPs to PNGs that keep transparency (alpha or color key from the theme INI):

```sh
python3 scripts/convert-theme-bmps.py /path/to/extracted
```

Core logic is importable as `quickxp_theme` under [`scripts/quickxp_theme/`](scripts/quickxp_theme/). XP import: Settings → Theme → Import… or `python3 scripts/import_xp_theme.py --install path.msstyles --dest <themes-root>`. Vista/7 projection is still open (roadmap #32).

## Testing

```sh
python3 -m pip install 'pytest>=8'   # once
./scripts/install-git-hooks.sh       # once per clone — pre-push runs the suite
./scripts/run-tests.sh               # pytest + qmltestrunner (required before push)
```

Pytest covers theme extract/convert helpers and `list_themes`; QML tests live under [`tests/qml/`](tests/qml/). Manual shell smoke: [`docs/SMOKE.md`](docs/SMOKE.md).

## Building `quickxp-preview`

On KDE, peeks call a small binary that uses KWin’s ScreenShot2 interface. Prefer:

```sh
./scripts/build-preview.sh
```

That writes `QuickXP/services/preview/quickxp-preview`. `TasksBridge.py` installs a companion `.desktop` file so KWin allows the restricted D-Bus call. The binary is gitignored — always build after cloning.

## Layout

| Path | Role |
| --- | --- |
| `shell.qml` | Quickshell entry (`import qs.QuickXP`) |
| `QuickXP/` | Runtime Quickshell module (deployed) |
| `QuickXP/Shell.qml` | Shell root, theme name |
| `QuickXP/Theme.qml` | Theme singleton |
| `QuickXP/Config.qml` | Persistent shell options (`dataPath/config.json`) |
| `QuickXP/controls/` | XP-themed buttons, tabs, checkboxes (Luna bitmaps) |
| `QuickXP/settings/` | Settings window, tabs, Start Properties menu |
| `QuickXP/taskbar/` | Taskbar, buttons, menus, peeks, pager |
| `QuickXP/tray/` | Notification area + clock |
| `QuickXP/services/` | KWin bridge, tasks script, preview helper |
| `QuickXP/themes/` | Luna, Aero stubs, extracted assets |
| `scripts/` | Setup, build-preview, theme extract/convert |
| `docs/ROADMAP.md` | Epic roadmap |
| `deploy.sh` | Symlink module into `~/.config/quickshell/default` |

Future features (Start, Settings, Desktop, …) land as sibling folders under `QuickXP/`.

## Roadmap

Planned work is organized as epics in [docs/ROADMAP.md](docs/ROADMAP.md): Settings, theme import, Start menu (classic → XP → search), Quick Launch, taskband grouping / icon-only / height, tray controls, Alt+Tab, lock screen, desktop, Explorer, and more.

## License

Add a license file when you choose one for the project. Theme assets extracted from Microsoft visual styles remain subject to their original terms; only use them in ways you are allowed to.
