"""Versioned uxtheme class → QuickXP logical key mapping (XP TEXTFILE INI)."""

from __future__ import annotations

# Map INI section (lowercase) → list of image bindings.
# Each binding: (image_key, source_field, group_updates)
# source_field: "imagefile" | "imagefile1" | "glyphimagefile" | "stockimagefile"
#
# group_updates are applied from the same section when present:
#   frames ← imageCount, borders ← SizingMargins, content ← ContentMargins, etc.

IMAGE_BINDINGS: dict[str, list[tuple[str, str]]] = {
    "button.pushbutton": [("buttonImage", "imagefile")],
    "button.checkbox": [("checkBoxImage", "imagefile1")],
    "button.radiobutton": [("radioButtonImage", "imagefile1")],
    "button.groupbox": [("groupBoxImage", "imagefile")],
    "combobox.dropdownbutton": [
        ("comboButtonImage", "imagefile"),
        ("comboButtonGlyphImage", "glyphimagefile"),
    ],
    "scrollbar.arrowbtn": [
        ("scrollArrowImage", "imagefile"),
        # Luna puts glyphs in ImageFile1/2 (size select), not GlyphImageFile.
        ("scrollArrowGlyphImage", "imagefile2"),
    ],
    "scrollbar.thumbbtnvert": [("scrollThumbVerticalImage", "imagefile")],
    "scrollbar.grippervert": [("scrollGripperVerticalImage", "imagefile")],
    "scrollbar.lowertrackvert": [("scrollShaftVerticalImage", "imagefile")],
    "spin": [("spinOutlineImage", "imagefile")],
    "spin.up": [
        ("spinUpBackgroundImage", "imagefile"),
        ("spinUpGlyphImage", "glyphimagefile"),
    ],
    "spin.down": [
        ("spinDownBackgroundImage", "imagefile"),
        ("spinDownGlyphImage", "glyphimagefile"),
    ],
    "tab.toptabitem": [("tabItemTopImage", "imagefile")],
    "tab.pane": [("tabPaneEdgeImage", "imagefile")],
    "tab.body": [("tabBackgroundImage", "imagefile1")],
    "tooltip.close": [
        ("tooltipCloseImage", "imagefile"),
        ("previewCloseImage", "imagefile"),
    ],
    "start::button": [("startButtonImage", "imagefile")],
    "taskbar.backgroundbottom": [("taskbarImage", "imagefile")],
    "taskband::toolbar.button": [("taskButtonImage", "imagefile")],
    "taskband::scrollbar.arrowbtn": [
        ("taskScrollArrowImage", "imagefile"),
        ("taskScrollArrowGlyphImage", "glyphimagefile"),
    ],
    "traynotifyhoriz::traynotify.background": [("trayImage", "imagefile")],
    "traynotifyhoriz::button": [("trayChevronImage", "imagefile")],
    "traynotifyhorizopen::button": [("trayChevronOpenImage", "imagefile")],
}

# Logical image keys that are optional chrome (omit without hard error).
OPTIONAL_IMAGES = frozenset(
    {
        "wallpaper",
        "startFlagImage",
    }
)

# Group property projections from INI sections.
GROUP_BINDINGS: list[dict] = [
    {
        "section": "button.pushbutton",
        "group": "button",
        "frames": "imagecount",
        "sizing": True,
        "disabled_text_section": "button.pushbutton(disabled)",
    },
    {
        "section": "tab.toptabitem",
        "group": "tab",
        "frames": "imagecount",
        "sizing": True,
        "fill_hint_key": "bodyFill",
        "fill_hint_section": "tab.body",
    },
    {
        "section": "button.checkbox",
        "group": "checkBox",
        "frames": "imagecount",
    },
    {
        "section": "button.radiobutton",
        "group": "radioButton",
        "frames": "imagecount",
    },
    {
        "section": "combobox.dropdownbutton",
        "group": "combo",
        "frames": "imagecount",
        "sizing": True,
    },
    {
        "section": "scrollbar.arrowbtn",
        "group": "scrollBar",
        "frames_key": "arrowFrames",
        "frames": "imagecount",
        "width_from_sysmetrics": True,
    },
    {
        "section": "scrollbar.thumbbtnvert",
        "group": "scrollBar",
        "frames_key": "thumbFrames",
        "frames": "imagecount",
        "sizing_prefix": "thumb",
    },
    {
        "section": "scrollbar.lowertrackvert",
        "group": "scrollBar",
        "frames_key": "shaftFrames",
        "frames": "imagecount",
    },
    {
        "section": "scrollbar.grippervert",
        "group": "scrollBar",
        "frames_key": "gripperFrames",
        "frames": "imagecount",
    },
    {
        "section": "spin.up",
        "group": "spin",
        "frames": "imagecount",
        "sizing": True,
    },
    {
        "section": "start::button",
        "group": "startButton",
        "frames": "imagecount",
        "sizing": True,
        "content": True,
        "font": True,
        "text_color": True,
        "shadow": True,
        "image_layout": True,
        "sizing_type": True,
    },
    {
        "section": "taskbar.backgroundbottom",
        "group": "taskbar",
        "sizing": True,
    },
    {
        "section": "button.groupbox",
        "group": "groupBox",
        "globals_edges": True,
    },
]

# SysMetrics / globals → theme.colors keys
COLOR_MAP = {
    "background": "desktop",
    "btnface": "button",
    "window": "window",  # often white; shell uses window chrome fill separately
    "menu": "menu",
    "highlight": "highlight",
    "highlighttext": "highlightText",
    "activecaption": "titleActive",
    "captiontext": "titleActiveText",
    "inactivecaption": "titleInactive",
    "inactivecaptiontext": "titleInactiveText",
}

# Fixed shell defaults when SysMetrics window fill is white (XP dialog face).
WINDOW_FACE_FALLBACK = "#ECE9D8"
BUTTON_TEXT_DEFAULT = "#000000"
TASKBAR_TEXT_DEFAULT = "#FFFFFF"
MENU_TEXT_DEFAULT = "#000000"
BORDER_FROM_HINT = "border"  # from button.pushbutton BorderColorHint when present
