#!/usr/bin/env python3
"""Create/sync GitHub Issues + Project from docs/ROADMAP.md structure.

Idempotent enough for first import: skips creating an issue if an open/closed
issue with the same title already exists in freitagdavid/QuickXP.
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import Optional

OWNER = "freitagdavid"
REPO = "QuickXP"
PROJECT_TITLE = "QuickXP Roadmap"


@dataclass
class Item:
    title: str
    body: str
    epic: str  # label epic:X
    kind: str  # roadmap:epic | roadmap:feature | roadmap:backlog
    status: str  # status:todo | status:partial | status:done
    parent_title: Optional[str] = None
    close: bool = False


def gh(*args: str, input_text: Optional[str] = None) -> str:
    cmd = ["gh", *args]
    result = subprocess.run(
        cmd,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed:\n{result.stderr}\n{result.stdout}")
    return result.stdout.strip()


def gh_json(*args: str):
    out = gh(*args)
    return json.loads(out) if out else None


def existing_titles() -> dict[str, dict]:
    """Map title -> issue dict for all issues."""
    issues = []
    after = None
    while True:
        args = [
            "api",
            f"repos/{OWNER}/{REPO}/issues",
            "--paginate",
            "-q",
            ".[] | {number, title, state, node_id, html_url}",
        ]
        # simpler: use gh issue list with json
        break
    data = gh_json(
        "issue",
        "list",
        "-R",
        f"{OWNER}/{REPO}",
        "--state",
        "all",
        "--limit",
        "500",
        "--json",
        "number,title,state,url,id",
    )
    return {i["title"]: i for i in data}


EPICS: list[Item] = []


def epic(id_: str, title: str, body: str, status: str = "status:todo") -> Item:
    item = Item(
        title=title,
        body=body.strip() + "\n\nSource: [`docs/ROADMAP.md`](../blob/main/docs/ROADMAP.md)\n",
        epic=f"epic:{id_}",
        kind="roadmap:epic",
        status=status,
        close=status == "status:done",
    )
    EPICS.append(item)
    return item


def feat(
    epic_id: str,
    parent_title: str,
    title: str,
    body: str,
    status: str = "status:todo",
) -> Item:
    return Item(
        title=title,
        body=body.strip()
        + f"\n\nParent epic: **{parent_title}**\nSource: [`docs/ROADMAP.md`](../blob/main/docs/ROADMAP.md)\n",
        epic=f"epic:{epic_id}",
        kind="roadmap:feature",
        status=status,
        parent_title=parent_title,
        close=status == "status:done",
    )


def backlog(title: str, body: str) -> Item:
    return Item(
        title=title,
        body=body.strip()
        + "\n\nTracked under Spec-derived backlog in [`docs/ROADMAP.md`](../blob/main/docs/ROADMAP.md).\n",
        epic="epic:9",  # park near Explorer later track; also labeled backlog
        kind="roadmap:backlog",
        status="status:todo",
    )


def build_items() -> list[Item]:
    items: list[Item] = []

    # --- Epic 0 ---
    e0 = "Epic 0 — Shell foundation"
    items.append(
        epic(
            "0",
            e0,
            """Shared seams so later epics do not hardcode XP-only assumptions.

**Partial:** config store, theme registry, generation policy, and `Settings.open` landed. Start popup host, app catalog, and shared controls atlas still open.""",
            "status:partial",
        )
    )
    items += [
        feat("0", e0, "[Epic 0] Generation / layout policy", "GenerationPolicy: shell generation from theme or Config.options.generation; per-feature generationOverrides (empty = follow shell). Settings → Theme UI. Consumers use GenerationPolicy.forItem(...).", "status:done"),
        feat("0", e0, "[Epic 0] Config store", "JsonAdapter at Quickshell.dataPath(config.json): theme, generation, generationOverrides, taskbar height, group/iconsOnly/lock/autoHide/quickLaunch/matchWindowBorders, lastSettingsTab.", "status:done"),
        feat("0", e0, "[Epic 0] Start popup host", "Open/close from Start button, dismiss on outside click / Esc, position above Start."),
        feat("0", e0, "[Epic 0] App catalog adapter", "Resolve .desktop entries, icons, launch; shared by classic Start, XP pins, and later search."),
        feat("0", e0, "[Epic 0] Installed theme registry", "ThemeRegistry.qml lists themes/*/theme.json; Apply switches Theme.name without restart.", "status:done"),
        feat("0", e0, "[Epic 0] Open Settings API", "Settings.open(tab) for Start/taskbar/desktop Properties deep-links.", "status:done"),
        feat("0", e0, "[Epic 0] Shared controls atlas", "Reusable themed pushbutton, checkbox, radio, edit, combo, tab, scrollbar, tooltip, message-box, and focus-rect states (VIS-11–23). Cover hover/pressed/disabled/focus."),
    ]

    # --- Epic S ---
    es = "Epic S — Central tabbed Settings window"
    items.append(
        epic(
            "S",
            es,
            """One tabbed configuration UI for the shell (XP-styled dialog chrome).

**Partial:** host + Theme/Taskbar stubs + Start right-click entry. Import/other tabs later.""",
            "status:partial",
        )
    )
    items += [
        feat("S", es, "[Epic S] Settings window host", "FloatingWindow with OK / Cancel / Apply (XP Display Properties pattern).", "status:done"),
        feat("S", es, "[Epic S] Settings tab bar", "Extensible tab list; deep-link via Settings.open.", "status:done"),
        feat("S", es, "[Epic S] Draft vs applied settings", "SettingsDraft; Theme tab previews without mutating live Theme.name until Apply.", "status:done"),
        feat("S", es, "[Epic S] Settings entry points", "Primary: right-click Start → Properties. Still open: empty-taskbar / desktop Properties; Start menu Control Panel stub.", "status:partial"),
        feat("S", es, "[Epic S] Theme tab", "Installed list + preview + Match window borders + shell generation / per-feature overrides. Import/Delete stubs until Epic T.", "status:done"),
        feat("S", es, "[Epic S] Taskbar tab", "Lock, auto-hide, group, icons-only, height, Quick Launch, presets. Later: keep-on-top, grouping policy, multi-row.", "status:partial"),
        feat("S", es, "[Epic S] Start Menu tab", "Classic vs XP dual-column; Customize depth (SMS-01–17); later Vista/7 search toggles."),
        feat("S", es, "[Epic S] Desktop tab", "Wallpaper, icon arrange/align, special-icon visibility, Show Desktop Icons (with Epic 6)."),
        feat("S", es, "[Epic S] Notification Area tab", "Hide inactive; per-icon show/hide; system control icons; clock; queue retention; balloons."),
        feat("S", es, "[Epic S] Appearance / Effects tab", "Luna vs Windows Classic style, color scheme, font size; menu/tooltip fade, shadows, mnemonics (DSP-09–17)."),
        feat("S", es, "[Epic S] Screen Saver tab", "Select saver, wait time, resume Welcome/password → lock (Epic 7)."),
        feat("S", es, "[Epic S] About tab", "Version, links, Open theme folder. Placeholder present."),
        feat("S", es, "[Epic S] Generation-aware tab labels", "Generation may hide or rename tabs (e.g. Vista Personalization) without splitting the config store."),
    ]

    # --- Epic T ---
    et = "Epic T — Theme import (msstyles → theme.json)"
    items.append(
        epic(
            "T",
            et,
            """End user loads an .msstyles and gets a working QuickXP theme with no hand-authored theme.json.

CLI extract/convert exists; gap is generation detection, INI→logical-key projector, Vista/7 parsers, and Settings → Theme Import wizard.""",
        )
    )
    items += [
        feat("T", et, "[Epic T] Library-wrap extract + convert CLI", "Make extract_xp_theme.py and convert-theme-bmps.py importable; keep thin CLIs."),
        feat("T", et, "[Epic T] Generation detection", "Heuristics → xp | vista | win7 | unknown (+ confidence / UI override)."),
        feat("T", et, "[Epic T] INI → theme.json projector", "Deterministic class→key table; ImageFile/SizingMargins/imageCount → logical keys. No manual mapping."),
        feat("T", et, "[Epic T] Theme install under user data", "Write themes/<slug>/ (extract + generated theme.json); keep repo Luna as fixture."),
        feat("T", et, "[Epic T] Settings Theme Import wizard", "Browse/drop .msstyles → detect → color scheme → progress → preview → Apply."),
        feat("T", et, "[Epic T] Color scheme picker", "NormalColor / Homestead / Metallic (and Vista/7 variants)."),
        feat("T", et, "[Epic T] Import error reporting", "Missing resources, unsupported generation, partial projection surfacing."),
        feat("T", et, "[Epic T] Prove XP loop on Luna + third-party msstyles", "Taskbar/Start/tray/buttons/dialog chrome/[Window.*] from INI."),
        feat("T", et, "[Epic T] Vista/7 msstyles projection (later)", "Aero resources, glass vs solid taskbar, set generation for layout policy."),
    ]

    # --- Epic K ---
    ek = "Epic K — KWin Aurorae window decorations"
    items.append(
        epic(
            "K",
            ek,
            "Generate and sync matching KWin Aurorae decorations so titlebars match the shell theme when Match window borders is on.",
        )
    )
    items += [
        feat("K", ek, "[Epic K] Map caption assets from INI/PNGs", "Titlebar strips, frame borders, close/min/max/restore/help glyph strips → Aurorae elements."),
        feat("K", ek, "[Epic K] Emit Aurorae package", "decoration.svgz, button SVGs, metadata.desktop, <id>rc; store under themes/<slug>/aurorae/."),
        feat("K", ek, "[Epic K] Sync decoration on Apply", "Install to ~/.local/share/aurorae/themes/<id>/ and select active decoration when Match window borders is on."),
        feat("K", ek, "[Epic K] Regenerate for installed themes", "CLI/GUI action for themes with extract but no Aurorae package yet (incl. Luna)."),
        feat("K", ek, "[Epic K] Titlebar preview in Theme tab", "Fake titlebar using same assets before Apply."),
        feat(
            "K",
            ek,
            "[Epic K] Vista/7 glass decoration (QML)",
            "QuickXP KWin QML decoration paints the loaded DWMWindow atlas (plate, reflection, highlight, outline, grouped caption buttons, title glow) and asks KWin to blur behind the frame. XP and Classic stay on Aurorae SVG.",
            "status:done",
        ),
    ]

    # --- Epic QA ---
    eqa = "Epic QA — Testing"
    items.append(
        epic(
            "QA",
            eqa,
            "pytest theme pipeline, QML helpers, thin shell smoke. Prefer cheap coverage; ship pytest scaffolding with Epic T.",
        )
    )
    items += [
        feat("QA", eqa, "[Epic QA] pytest for theme tooling", "Fixtures for extract, convert, detect, INI projection, Aurorae emission. Run pytest tests/."),
        feat("QA", eqa, "[Epic QA] pytest for Python bridges", "Optional TasksBridge helpers once notification/theme install logic lands."),
        feat("QA", eqa, "[Epic QA] QML helper tests (qmltestrunner)", "Pure logic: paging, grouping policy, Start model, theme merge — mocked services."),
        feat("QA", eqa, "[Epic QA] Shell smoke checklist/scripts", "Notification queue, open Start, Theme.name switch, Run dialog, hotkeys."),
        feat("QA", eqa, "[Epic QA] CI pytest on push (optional later)", "GitHub Action for pytest; QML tests if headless imports resolve."),
    ]

    # --- Epic H ---
    eh = "Epic H — Shell hotkeys"
    items.append(
        epic(
            "H",
            eh,
            "Central shortcut ownership for Start, Run, session, and taskband. Coordinate with KWin/Plasma global shortcuts.",
        )
    )
    items += [
        feat("H", eh, "[Epic H] Start hotkeys (Win / Ctrl+Esc)", "Open Start; Esc/outside dismiss (with Epic 1 host)."),
        feat("H", eh, "[Epic H] Win+R / Win+E / Win+F / Win+L", "Run, Explorer stub, Search stub, Lock — wire to epics R/9/7."),
        feat("H", eh, "[Epic H] Desktop hotkeys (Win+D / Win+M)", "Show Desktop / minimize all / Shift+Win+M restore."),
        feat("H", eh, "[Epic H] Alt+Esc window cycle", "Cycle eligible windows without Alt+Tab overlay (WIN-16)."),
        feat("H", eh, "[Epic H] Win+Tab taskbar focus cycle (XP default)", "Cycle taskbar button focus — must not open Flip 3D/overview under generation:xp."),
        feat("H", eh, "[Epic H] Ctrl+Shift+Esc / Ctrl+Alt+Delete", "Task Manager launch; Security surface per session config."),
        feat("H", eh, "[Epic H] Desktop Alt+F4 → Turn Off Computer", "Invoke session UI (Epic 7), not only close a window."),
    ]

    # --- Epic R ---
    er = "Epic R — Run dialog"
    items.append(
        epic(
            "R",
            er,
            "First-class Run UI (LNK-17–21): Open/Browse/OK/Cancel, launch resolution, history, Win+R + Start → Run.",
        )
    )
    items += [
        feat("R", er, "[Epic R] Run dialog chrome", "Open field, Browse, OK, Cancel; XP-styled shared controls."),
        feat("R", er, "[Epic R] Launch resolution", "Apps, paths, documents, folders, URLs; env expansion; honest failure UI."),
        feat("R", er, "[Epic R] Run history / autocomplete", "Per-user remembered entries; clear via Start Customize when available."),
        feat("R", er, "[Epic R] Run entry points", "Win+R (Epic H); Classic and XP Start → Run."),
    ]

    # --- Epic 1 ---
    e1 = "Epic 1 — Classic Start menu (single-column)"
    items.append(
        epic(
            "1",
            e1,
            "Ship first for Start UX: one column of cascaded folders/items plus session commands. No dual-column, user tile, or search box.",
        )
    )
    items += [
        feat("1", e1, "[Epic 1] Open Classic Start from Start button", "Left-click opens menu; right-click Properties/Settings (Epic S)."),
        feat("1", e1, "[Epic 1] Programs cascade", "Recursive flyouts from user/system menus; merge per-user and all-users."),
        feat("1", e1, "[Epic 1] Fixed shell items", "Documents / settings / Help / Search / Run rows."),
        feat("1", e1, "[Epic 1] Favorites / recent docs (optional)", "Classic Documents/Recent submenu if cheap after Programs."),
        feat("1", e1, "[Epic 1] Bottom session rows", "Log Off, Shut Down → Epic 7 dialogs/APIs."),
        feat("1", e1, "[Epic 1] Classic Start keyboard nav", "Up/down, Enter, Esc, mnemonics, hover/timeout submenu (SMS-24)."),
        feat("1", e1, "[Epic 1] Highlight newly installed (optional)", "After Programs works."),
        feat("1", e1, "[Epic 1] Personalized menus (later)", "Hide infrequently used Classic entries until expand (SMS-23)."),
        feat("1", e1, "[Epic 1] Classic Start Customize", "Settings → Start Menu Add/Remove/Advanced/Clear (SMS-18–22)."),
    ]

    # --- Epic 2 ---
    e2 = "Epic 2 — XP dual-column Start menu"
    items.append(
        epic(
            "2",
            e2,
            "Default Luna Start when generation is XP. Pins, MFU, All Programs flyout, special folders, Log Off / Turn Off.",
        )
    )
    items += [
        feat("2", e2, "[Epic 2] Two-column Start frame + user tile", "Luna left/right skins; interactive account picture (STA-32)."),
        feat("2", e2, "[Epic 2] Pinned apps", "Pin/unpin, drag reorder, persisted; default Internet/E-mail handlers (STA-05)."),
        feat("2", e2, "[Epic 2] Most-frequent list", "Usage scoring with decay; Remove from This List ≠ Unpin; Clear List (STA-10–14)."),
        feat("2", e2, "[Epic 2] All Programs flyout", "Reuse classic Programs cascade."),
        feat("2", e2, "[Epic 2] Right-column special folders", "Documents, Pictures, Music, Computer, Network, Control Panel, etc. (STA-24–29)."),
        feat("2", e2, "[Epic 2] Help / Search / Run rows", "XP Search UI stub; Run → Epic R."),
        feat("2", e2, "[Epic 2] Bottom Log Off / Turn Off buttons", "Luna art; session dialogs."),
        feat("2", e2, "[Epic 2] Layout switch classic vs XP", "Theme/properties can still select classic single-column."),
        feat("2", e2, "[Epic 2] Start Customize depth", "SMS-01–17 via Settings → Start Menu."),
    ]

    # --- Epic 3 ---
    e3 = "Epic 3 — Vista/7 Start search"
    items.append(
        epic(
            "3",
            e3,
            "After dual-column: search box, ranked app/doc/setting results, keyboard-first. Jump lists optional later.",
        )
    )
    items += [
        feat("3", e3, "[Epic 3] Start search box UI", "Focused field at bottom; type-to-filter without closing menu."),
        feat("3", e3, "[Epic 3] App / document / setting results", "Ranked list replacing/overlaying left column while typing."),
        feat("3", e3, "[Epic 3] Keyboard-first search results", "Arrows + Enter to launch; Esc clears or closes."),
        feat("3", e3, "[Epic 3] Jump-list stubs (Win7, optional later)", "Optional slice inside pinned/recent; not required for first search ship."),
    ]

    # --- Epic 4 ---
    e4 = "Epic 4 — Quick Launch, Show Desktop, toolbars"
    items.append(
        epic(
            "4",
            e4,
            "XP Quick Launch between Start and task band, Show Desktop, other desk-band toolbars, Win7 far-right Show Desktop.",
        )
    )
    items += [
        feat("4", e4, "[Epic 4] Quick Launch strip", "Small icons; launch; drag-drop add; reorder; remove; persist in config."),
        feat("4", e4, "[Epic 4] Show Desktop", "Minimize all / restore prior states including dialogs where possible (TSK-27)."),
        feat("4", e4, "[Epic 4] Quick Launch Settings toggle", "Taskbar tab show/hide Quick Launch."),
        feat("4", e4, "[Epic 4] Win7 far-right Show Desktop", "Thin tray-edge button when generation is win7."),
        feat("4", e4, "[Epic 4] Quick Launch overflow chevron", "Launchers that do not fit (BAR-08)."),
        feat("4", e4, "[Epic 4] Toolbars beyond Quick Launch", "Desktop, Links, New Toolbar; Show Text/Title; grippers (BAR-09–15)."),
        feat("4", e4, "[Epic 4] Toolbar enable/disable persistence", "Taskbar Toolbars submenu for visibility, order, widths (BAR-20)."),
        feat("4", e4, "[Epic 4] Toolbar height scaling", "Icons scale with taskbar height unit (Epic 5)."),
    ]

    # --- Epic 5 ---
    e5 = "Epic 5 — Taskband behavior"
    items.append(
        epic(
            "5",
            e5,
            "Grouping policy, icon-only, height/multi-row, chrome menu, auto-hide, attention flash. groupButtons and iconsOnly are independent.",
        )
    )
    items += [
        feat("5", e5, "[Epic 5] Crowding-triggered grouping (XP)", "Group when space tight; reverse when room; XP preset default (TSK-16)."),
        feat("5", e5, "[Epic 5] Always-grouped policy (modern)", "Optional for icon-preview preset; express policy explicitly in config."),
        feat("5", e5, "[Epic 5] XP list group popup", "Vertical menu of window titles; not thumbnails."),
        feat("5", e5, "[Epic 5] Thumbnail strip group popup", "N peeks side by side when iconsOnly; raise-without-focus on hover."),
        feat("5", e5, "[Epic 5] Taskbar height scaling", "24–72px unit; scale sprites preserving aspect ratio."),
        feat("5", e5, "[Epic 5] Multi-row / vertical taskbar", "Unlocked grow to multiple rows or wider vertical bar (TSK-03–04)."),
        feat("5", e5, "[Epic 5] Click activate/minimize behaviors", "TSK-13/14; Ctrl+multi-select; drag-hover activate."),
        feat("5", e5, "[Epic 5] Empty-taskbar context menu", "Toolbars, Lock, Cascade, Tile, Show Desktop, Task Manager, Properties."),
        feat("5", e5, "[Epic 5] Cascade / tile / show desktop actions", "Extend kwin/tasks.js and Wayland path where possible."),
        feat("5", e5, "[Epic 5] Auto-hide taskbar", "Slide off-screen; reveal on edge hover (TSK-05)."),
        feat("5", e5, "[Epic 5] Keep on top + work area", "Reserve work area; full-screen visibility policy (TSK-06–08)."),
        feat("5", e5, "[Epic 5] Attention flash on task button", "Unused Luna task-button frame when window demands attention."),
    ]

    # --- Epic C ---
    ec = "Epic C — Tray system controls"
    items.append(
        epic(
            "C",
            ec,
            "Volume mixer (Win7-style, first), network, Bluetooth, brightness, drives, battery, clock Properties.",
        )
    )
    items += [
        feat("C", ec, "[Epic C] Tray volume mixer (first priority)", "Adapt quickshell-examples/mixer into tray popup; scroll/middle-click; per-app volume."),
        feat("C", ec, "[Epic C] Default output device switch", "List sinks → preferredDefaultAudioSink."),
        feat("C", ec, "[Epic C] Per-app output routing", "Move app stream to different sink; set as default for all."),
        feat("C", ec, "[Epic C] Mic volume/mute (optional)", "Default source in same popup or section."),
        feat("C", ec, "[Epic C] Network tray control", "NM status icon; Wi-Fi/Ethernet connect/disconnect popup."),
        feat("C", ec, "[Epic C] Bluetooth tray control", "Adapter on/off; paired devices (BlueZ/portal)."),
        feat("C", ec, "[Epic C] Brightness tray control", "Backlight slider; hide when no device."),
        feat("C", ec, "[Epic C] Battery / power tray icon", "Charge/AC state; hide without battery (TRY-15)."),
        feat("C", ec, "[Epic C] Removable drives", "UDisks2 open / safely remove."),
        feat("C", ec, "[Epic C] Clock Show/hover/double-click", "Show Clock; hover date; double-click Date/Time Properties (not Vista calendar for XP)."),
    ]

    # --- Epic A ---
    ea = "Epic A — Alt+Tab / task switcher"
    items.append(
        epic(
            "A",
            ea,
            "QuickXP-owned Alt+Tab overlay. Adapt quickshell-overview patterns; KWin-first backend; XP list then preview switcher.",
        )
    )
    items += [
        feat("A", ea, "[Epic A] Alt+Tab overlay + state machine", "Hold Alt, Tab cycle, release activate; click; Esc cancel."),
        feat("A", ea, "[Epic A] XP icon+title switcher skin", "Horizontal/grid of icons + titles; no live thumbs required."),
        feat("A", ea, "[Epic A] Thumbnail preview switcher", "Overview-inspired cards + KWin ScreenShot2 capture."),
        feat("A", ea, "[Epic A] Grab compositor Alt+Tab shortcut", "Disable/override KWin/Plasma (and Hyprland) default; document steps."),
        feat("A", ea, "[Epic A] Optional Super+Tab full overview", "Only when generation/Settings opts in — not XP Win+Tab default."),
        feat("A", ea, "[Epic A] Hyprland backend adapter (optional)", "Reuse quickshell-overview services under GPL when vendoring."),
    ]

    # --- Epic 6 ---
    e6 = "Epic 6 — Desktop"
    items.append(
        epic(
            "6",
            e6,
            "Wallpaper, icon layer, special shell icons, Recycle Bin, arrange/align, desktop context menu.",
        )
    )
    items += [
        feat("6", e6, "[Epic 6] Wallpaper surface", "center/tile/stretch; importer may copy from .theme."),
        feat("6", e6, "[Epic 6] Desktop icon layer", "Select, open, drag, rename; marquee/Ctrl/Shift; type-to-select."),
        feat("6", e6, "[Epic 6] Special shell icons", "Recycle Bin, My Computer, My Documents, My Network Places visibility (DES-04)."),
        feat("6", e6, "[Epic 6] Recycle Bin operations", "Empty/full state; drag-to-delete; Empty/Open/restore/Properties (BIN-01–14)."),
        feat("6", e6, "[Epic 6] Arrange / align to grid", "Align to Grid, Auto Arrange, Arrange Icons By (DES-11–13)."),
        feat("6", e6, "[Epic 6] Show Desktop Icons toggle", "Hide icon layer, keep wallpaper (DES-14)."),
        feat("6", e6, "[Epic 6] Desktop context menu", "Refresh, Paste, New, Properties → Settings.open(desktop)."),
        feat("6", e6, "[Epic 6] Multi-monitor icon placement recovery", "After resolution/topology changes (DES-24)."),
        feat("6", e6, "[Epic 6] Desktop Cleanup Wizard (later)", "Unused shortcuts → Unused Desktop Shortcuts (DES-21–23)."),
    ]

    # --- Epic G ---
    eg = "Epic G — Vista Sidebar gadgets"
    items.append(
        epic(
            "G",
            eg,
            """Docked Vista Sidebar first. Free-floating placement (Windows 7) is a later slice and reuses the same gadget instances.

On for generation vista and an explicit setting. Off for generation xp. generation win7 stays off until free placement, which is the Win7 default.

Built-in gadgets only. No third-party .gadget packages, ActiveX/HTML hosts, or the online gadget gallery. Active Desktop stays out of scope (Epic 6).""",
        )
    )
    items += [
        feat("G", eg, "[Epic G] Sidebar host", "Right-edge dock (left optional); show/hide; above the desktop icon layer; generation-gated."),
        feat("G", eg, "[Epic G] Gadget frame", "Chrome, close, in-bar reorder, per-gadget opacity."),
        feat("G", eg, "[Epic G] Built-in gallery", "Add from a fixed catalog, not downloaded packages."),
        feat("G", eg, "[Epic G] Gadget persistence", "Which gadgets, order, and options in the existing config store."),
        feat("G", eg, "[Epic G] Sidebar properties", "Side, always on top, start with the shell."),
        feat("G", eg, "[Epic G] Clock gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Calendar gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Contacts gadget", "Vista only."),
        feat("G", eg, "[Epic G] CPU Meter gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Currency gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Feed Headlines gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Notes gadget", "Vista only."),
        feat("G", eg, "[Epic G] Picture Puzzle gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Slide Show gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Stocks gadget", "Vista only."),
        feat("G", eg, "[Epic G] Weather gadget", "Vista and Windows 7."),
        feat("G", eg, "[Epic G] Windows Media Center gadget", "Windows 7 only. The full Media Center / Royale product stays out of scope."),
        feat("G", eg, "[Epic G] Free-floating placement (later)", "Undock onto the desktop; Win7 default."),
    ]

    # --- Epic 7 ---
    e7 = "Epic 7 — Session dialogs and lock screen"
    items.append(
        epic(
            "7",
            e7,
            "Turn Off / Log Off / Windows Security dialogs plus QuickXP-owned Windows-style lock screen (XP Welcome first).",
        )
    )
    items += [
        feat("7", e7, "[Epic 7] Turn Off Computer dialog", "Stand by / Turn off / Restart; Shift→Hibernate when available (SES-11)."),
        feat("7", e7, "[Epic 7] Classic Shut Down vs Welcome power panel", "Selectable by login/Start mode (SES-13)."),
        feat("7", e7, "[Epic 7] Log Off dialog", "Log off / Switch user if available."),
        feat("7", e7, "[Epic 7] Windows Security dialog", "Ctrl+Alt+Delete → lock/logoff/shutdown/TM per config (SES-18–19)."),
        feat("7", e7, "[Epic 7] XP Welcome-style lock screen", "Full-bleed wallpaper, user tile, password, Go; secure surface."),
        feat("7", e7, "[Epic 7] Lock unlock backend", "PAM/polkit/logind; coordinate so Plasma locker does not fight QuickXP."),
        feat("7", e7, "[Epic 7] Vista/7 lock skin (later)", "Centered tile, ease-of-access/power; same unlock backend."),
        feat("7", e7, "[Epic 7] Startup folder launch", "User/common Startup entries after shell comes up (LNK-23 / SES-23)."),
        feat("7", e7, "[Epic 7] Screen saver → lock integration", "Wait time and resume-to-lock via Settings (DSP-06–07)."),
    ]

    # --- Epic 8 ---
    e8 = "Epic 8 — Attention and notifications"
    items.append(
        epic(
            "8",
            e8,
            "NotificationServer host, tray queue, balloons, generation-gated retention, per-icon Customize. Can ship early after foundation/tray.",
        )
    )
    items += [
        feat("8", e8, "[Epic 8] NotificationServer host", "Own freedesktop bus; trackedNotifications; dismiss/expire."),
        feat("8", e8, "[Epic 8] Tray notification queue UI", "Badge/icon; scrollable list; per-item dismiss; Clear all; actions."),
        feat("8", e8, "[Epic 8] Arrival balloons / toasts", "Short XP balloon tip; Vista/7 toast later; generation retention policy."),
        feat("8", e8, "[Epic 8] Per-icon Customize Notifications", "Always show/hide/inactive; Restore Defaults (TRY-07–09)."),
        feat("8", e8, "[Epic 8] Transient/replace/expire handling", "Honor transient, replace-id, expire timeouts."),
    ]

    # --- Epic 9 ---
    e9 = "Epic 9 — Explorer (later track)"
    items.append(
        epic(
            "9",
            e9,
            "Folder windows with Luna chrome after Start, Quick Launch, and desktop exist. Deeper inventory stays in long-form spec.",
        )
    )
    items += [
        feat("9", e9, "[Epic 9] Folder windows", "Browse filesystem with Luna chrome."),
        feat("9", e9, "[Epic 9] Explorer navigation", "Back, Up, address bar."),
        feat("9", e9, "[Epic 9] Explorer views", "Icons / list / details."),
        feat("9", e9, "[Epic 9] Tasks pane", "XP common tasks sidebar."),
    ]

    # --- Epic 10 ---
    e10 = "Epic 10 — Computer window"
    items.append(
        epic(
            "10",
            e10,
            "Generation-skinned Computer root (XP My Computer, Vista/7 Computer). "
            "Drive groups, open/eject/properties, XP tasks pane, Vista/7 command bar. "
            "Start and Win+E open this window. Folder browsing stays Epic 9.",
        )
    )
    items += [
        feat(
            "10",
            e10,
            "[Epic 10] Computer window shell and generation chrome",
            "One window skinned by generation: XP My Computer menus/toolbar/address/status; "
            "Vista/7 Computer breadcrumb, command bar, and panes.",
        ),
        feat(
            "10",
            e10,
            "[Epic 10] Drive groups",
            "Fixed mounts, removable disks (DrivesBridge), mounted network filesystems, "
            "and the XP user-folder group (home and ~/Public).",
        ),
        feat(
            "10",
            e10,
            "[Epic 10] Open, eject, and properties",
            "Open a mount in the system file manager, eject removable media, "
            "General-style properties (label, file system, used, free).",
        ),
        feat(
            "10",
            e10,
            "[Epic 10] XP tasks pane, menus, toolbar, address, status",
            "Common Tasks (System Tasks, Other Places, Details), menu bar, standard toolbar, "
            "text address, status bar.",
        ),
        feat(
            "10",
            e10,
            "[Epic 10] Vista/7 command bar, breadcrumb, search, nav, details",
            "Organize command bar, breadcrumb address, search filter, navigation pane, "
            "bottom details pane. Win7 omits Open Control Panel. Libraries deferred.",
        ),
        feat(
            "10",
            e10,
            "[Epic 10] Start and Win+E open Computer",
            "Start → My Computer and Win+E open this window instead of computer:///.",
        ),
    ]

    # --- Spec backlog ---
    items += [
        backlog("[Backlog] Search Companion", "XP Search Results + Companion pane (SEA-*); Win+F / Start → Search for XP generation."),
        backlog("[Backlog] Sound scheme", "Map shell events to assets (ACC-17); provenance of XP WAV/fonts/wallpapers separate."),
        backlog("[Backlog] Task Manager UI", "Optional Applications/Processes/Performance after system-TM launch works (SES-21–22)."),
        backlog("[Backlog] Toolkit theming (Qt/GTK)", "Luna/Classic for client apps — separate from shell chrome (LNX-14)."),
        backlog("[Backlog] Reference validation scenarios", "Inventory TST-* as smoke/regression prompts once features exist."),
    ]

    return items


def create_issue(item: Item) -> dict:
    labels = [item.kind, item.status, item.epic]
    args = [
        "issue",
        "create",
        "-R",
        f"{OWNER}/{REPO}",
        "--title",
        item.title,
        "--body",
        item.body,
    ]
    for lab in labels:
        args += ["--label", lab]
    url = gh(*args)
    # fetch number
    num = int(url.rstrip("/").split("/")[-1])
    issue = {"number": num, "title": item.title, "url": url, "state": "open"}
    if item.close:
        gh(
            "issue",
            "close",
            str(num),
            "-R",
            f"{OWNER}/{REPO}",
            "--reason",
            "completed",
        )
        issue["state"] = "closed"
    return issue


def ensure_project() -> tuple[int, str]:
    """Return (number, id) for PROJECT_TITLE under OWNER."""
    projects = gh_json("project", "list", "--owner", OWNER, "--limit", "50", "--format", "json")
    # format may be {projects: [...]} or list depending on gh version
    plist = projects.get("projects", projects) if isinstance(projects, dict) else projects
    for p in plist:
        if p.get("title") == PROJECT_TITLE:
            return int(p["number"]), p["id"]
    created = gh_json(
        "project",
        "create",
        "--owner",
        OWNER,
        "--title",
        PROJECT_TITLE,
        "--format",
        "json",
    )
    return int(created["number"]), created["id"]


def link_project(number: int) -> None:
    try:
        gh("project", "link", str(number), "--owner", OWNER, "--repo", f"{OWNER}/{REPO}")
    except RuntimeError as e:
        if "already" in str(e).lower():
            return
        # older gh may use different flags
        print(f"warn: project link: {e}", file=sys.stderr)


def add_to_project(project_number: int, issue_url: str) -> None:
    gh(
        "project",
        "item-add",
        str(project_number),
        "--owner",
        OWNER,
        "--url",
        issue_url,
    )


def set_parent(child_number: int, parent_number: int) -> None:
    # GraphQL addSubIssue — treat already-linked as success
    query = """
    mutation($parent:ID!, $child:ID!) {
      addSubIssue(input: {issueId: $parent, subIssueId: $child}) {
        issue { number }
      }
    }
    """
    parent = gh_json("api", f"repos/{OWNER}/{REPO}/issues/{parent_number}")
    child = gh_json("api", f"repos/{OWNER}/{REPO}/issues/{child_number}")
    try:
        out = gh(
            "api",
            "graphql",
            "-f",
            f"query={query}",
            "-f",
            f"parent={parent['node_id']}",
            "-f",
            f"child={child['node_id']}",
        )
        if out and '"errors"' in out:
            lower = out.lower()
            if "duplicate" in lower or "only have one parent" in lower:
                return
            print(f"warn: sub-issue link {child_number}->{parent_number}: {out}", file=sys.stderr)
    except RuntimeError as e:
        msg = str(e).lower()
        if "duplicate" in msg or "only have one parent" in msg:
            return
        # sub-issues may not be enabled; non-fatal
        print(f"warn: sub-issue link {child_number}->{parent_number}: {e}", file=sys.stderr)


def main() -> int:
    dry = "--dry-run" in sys.argv
    items = build_items()
    print(f"Planned items: {len(items)}", file=sys.stderr)

    if dry:
        for i in items:
            print(f"{i.status:14} {i.kind:16} {i.title}")
        return 0

    known = existing_titles()
    created: dict[str, dict] = {}
    title_to_issue: dict[str, dict] = dict(known)

    for item in items:
        if item.title in title_to_issue:
            print(f"skip exists: {item.title}", file=sys.stderr)
            created[item.title] = title_to_issue[item.title]
            continue
        issue = create_issue(item)
        title_to_issue[item.title] = issue
        created[item.title] = issue
        print(f"created #{issue['number']}: {item.title}", file=sys.stderr)
        time.sleep(0.3)  # be gentle on API

    # parents
    for item in items:
        if not item.parent_title:
            continue
        child = title_to_issue.get(item.title)
        parent = title_to_issue.get(item.parent_title)
        if child and parent:
            set_parent(child["number"], parent["number"])
            time.sleep(0.15)

    # project
    try:
        number, _pid = ensure_project()
        link_project(number)
        for item in items:
            issue = title_to_issue[item.title]
            url = issue.get("url") or f"https://github.com/{OWNER}/{REPO}/issues/{issue['number']}"
            try:
                add_to_project(number, url)
            except RuntimeError as e:
                if "already" in str(e).lower():
                    continue
                print(f"warn: item-add {url}: {e}", file=sys.stderr)
            time.sleep(0.2)
        print(f"Project: https://github.com/users/{OWNER}/projects/{number}")
    except RuntimeError as e:
        print(f"ERROR creating/populating project (need project scope?): {e}", file=sys.stderr)
        print("Issues were still created. Re-run after: gh auth refresh -h github.com -s project,read:project", file=sys.stderr)
        return 2

    # write mapping for agents
    mapping = {
        "project": f"https://github.com/users/{OWNER}/projects/{number}",
        "project_number": number,
        "issues": {
            t: {"number": i["number"], "url": i.get("url") or f"https://github.com/{OWNER}/{REPO}/issues/{i['number']}", "state": i.get("state")}
            for t, i in title_to_issue.items()
            if t in {x.title for x in items}
        },
    }
    out_path = "docs/github-roadmap-map.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(mapping, f, indent=2)
        f.write("\n")
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
