# QuickXP

A [Quickshell](https://quickshell.org/) desktop shell inspired by Windows XP, with room to grow toward Vista and Windows 7. The goal is an XP-like taskbar and shell that can also pick up later-era features (window peek, icon-only taskbar, Win7-style volume mixer, and so on).

Today the project is a Luna-themed taskbar: Start button chrome, task buttons, paging, system menus, tray, clock, and KWin window peeks. The Start menu and most of the rest of the shell are still on the roadmap — see [docs/ROADMAP.md](docs/ROADMAP.md).

## Requirements

- [Quickshell](https://quickshell.org/)
- Qt 6
- On KDE / Plasma: KWin (window list + peeks go through a small KWin script and D-Bus bridge)
- Python 3 with `dbus-python` and PyGObject (for `TasksBridge.py` on KDE)
- Optional theme tooling: Python 3 only (stdlib)

Window peeks also need the `quickxp-preview` helper (see below).

## Quick start

From the repo root:

```sh
./deploy.sh
quickshell
```

`deploy.sh` symlinks `src` into `~/.config/quickshell/default/QuickXP` and copies `shell.qml` into that config. Restart or reload Quickshell after pulling changes.

The active theme defaults to Luna (`theme: "luna"` in [`src/Shell.qml`](src/Shell.qml)). Themes live under [`src/themes/`](src/themes/) as `theme.json` plus image assets.

## What works now

- Bottom taskbar with Luna sprites (Start button, plate, task buttons, tray, pager arrows)
- Task list from KWin (KDE) or foreign toplevels elsewhere
- Activate / minimize, right-click system menu, crowding pager
- Hover window peek on KDE (falls back to title tooltip otherwise)
- System tray (StatusNotifier) with hide-inactive chevron and clock
- Live-reloading themes via [`src/Theme.qml`](src/Theme.qml)

## Theme tooling

Extract bitmaps and settings from a Windows XP `.msstyles` / `Shellstyle.dll` tree:

```sh
python3 src/scripts/extract_xp_theme.py /path/to/theme -o /path/to/out
```

Convert extracted BMPs to PNGs that keep transparency (alpha or color key from the theme INI):

```sh
python3 scripts/convert-theme-bmps.py /path/to/extracted
```

Mapping into QuickXP’s `theme.json` is still manual for Luna; automating import and Settings UI is planned in the roadmap.

## Building `quickxp-preview`

On KDE, peeks call a small binary that uses KWin’s ScreenShot2 interface:

```sh
cd src
g++ -O2 -o quickxp-preview quickxp-preview.cpp $(pkg-config --cflags --libs Qt6DBus Qt6Gui)
```

`TasksBridge.py` installs a companion `.desktop` file so KWin allows the restricted D-Bus call. Rebuild after changing the C++ source; `deploy.sh` does not compile it.

## Layout

| Path | Role |
| --- | --- |
| `shell.qml` | Quickshell entry (loads `Shell`) |
| `src/Shell.qml` | Shell root, theme name |
| `src/TaskBar.qml` | Taskbar, Start button, tray host |
| `src/TaskList.qml` / `TaskButton.qml` / … | Task band, menus, peeks, pager |
| `src/Tray.qml` | Notification area + clock |
| `src/Theme.qml` | Theme singleton |
| `src/themes/` | Luna, Aero stubs, extracted assets |
| `src/kwin/tasks.js` | KWin script for the window list |
| `src/TasksBridge.py` | Session-bus bridge + preview helper |
| `docs/ROADMAP.md` | Epic roadmap |

## Roadmap

Planned work is organized as epics in [docs/ROADMAP.md](docs/ROADMAP.md): Settings, theme import, Start menu (classic → XP → search), Quick Launch, taskband grouping / icon-only / height, tray controls, Alt+Tab, lock screen, desktop, Explorer, and more.

## License

Add a license file when you choose one for the project. Theme assets extracted from Microsoft visual styles remain subject to their original terms; only use them in ways you are allowed to.
