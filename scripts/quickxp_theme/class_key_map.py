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
    # Window caption / frame / buttons (Epic K → Aurorae).
    "window.caption": [("captionImage", "imagefile")],
    "window.frameleft": [("frameLeftImage", "imagefile")],
    "window.frameright": [("frameRightImage", "imagefile")],
    "window.framebottom": [("frameBottomImage", "imagefile")],
    "window.closebutton": [
        ("closeButtonImage", "imagefile"),
        ("closeGlyphImage", "imagefile3"),
    ],
    "window.minbutton": [
        ("minButtonImage", "imagefile"),
        ("minGlyphImage", "imagefile3"),
    ],
    "window.maxbutton": [
        ("maxButtonImage", "imagefile"),
        ("maxGlyphImage", "imagefile3"),
    ],
    "window.restorebutton": [
        ("restoreButtonImage", "imagefile"),
        ("restoreGlyphImage", "imagefile3"),
    ],
    "window.helpbutton": [
        ("helpButtonImage", "imagefile"),
        ("helpGlyphImage", "imagefile3"),
    ],
    # XP dual-column Start panel (Epic 2).
    "startpanel.userpane": [("startUserPanelImage", "imagefile")],
    "startpanel.userpicture": [("startUserTileImage", "imagefile")],
    "startpanel.proglist": [("startPanelMfuBackgroundImage", "imagefile")],
    "startpanel.proglistseparator": [("startPanelProgramsSeparatorImage", "imagefile")],
    "startpanel.moreprograms": [("startPanelMoreProgBackgroundImage", "imagefile")],
    "startpanel.moreprogramsarrow": [("startPanelMoreProgArrowImage", "imagefile")],
    "startpanel.moreprogramsarrow(hot)": [("startPanelMoreProgArrowHotImage", "imagefile")],
    "startpanel.placeslist": [("startPanelPlacesBackgroundImage", "imagefile")],
    "startpanel.placeslistseparator": [("startPanelPlacesSeparatorImage", "imagefile")],
    "startpanel.logoff": [("startPanelLogoffBackgroundImage", "imagefile")],
    "startpanel.logoffbuttons": [("startPanelLogoffButtonsImage", "imagefile")],
    "startpanel.logoffbuttons(hot)": [("startPanelLogoffButtonsHotImage", "imagefile")],
    # XP All Programs flyout (StartMenu::Toolbar / StartGroupBackground).
    "startmenu::toolbar": [("startGroupBackgroundImage", "imagefile")],
}

# Logical image keys that are optional chrome (omit without hard error).
OPTIONAL_IMAGES = frozenset(
    {
        "wallpaper",
        "startFlagImage",
        "captionImage",
        "captionActiveImage",
        "captionInactiveImage",
        "frameLeftImage",
        "frameRightImage",
        "frameBottomImage",
        "closeButtonImage",
        "closeGlyphImage",
        "minButtonImage",
        "minGlyphImage",
        "maxButtonImage",
        "maxGlyphImage",
        "restoreButtonImage",
        "restoreGlyphImage",
        "helpButtonImage",
        "helpGlyphImage",
        "startUserPanelImage",
        "startUserTileImage",
        "startPanelMfuBackgroundImage",
        "startPanelPlacesBackgroundImage",
        "startPanelMoreProgBackgroundImage",
        "startPanelMoreProgArrowImage",
        "startPanelMoreProgArrowHotImage",
        "startPanelLogoffBackgroundImage",
        "startPanelLogoffButtonsImage",
        "startPanelLogoffButtonsHotImage",
        "startPanelProgramsSeparatorImage",
        "startPanelPlacesSeparatorImage",
        "startGroupBackgroundImage",
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
        "section": "window.caption",
        "group": "caption",
        "frames": "imagecount",
        "sizing": True,
        "content": True,
        "image_layout": True,
        "sizing_type": True,
    },
    {
        "section": "startpanel.userpane",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "userBorder",
        "text_color": True,
        "text_color_key": "userNameColor",
        "shadow": True,
        "shadow_color_key": "userNameShadow",
        "fill_hint_key": "userFill",
    },
    {
        # UserTileBackground underlay — face sits in ContentMargins.
        "section": "startpanel.userpicture",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "tileBorder",
        "content": True,
        "content_prefix": "tileContent",
        "fill_hint_key": "tileFill",
    },
    {
        "section": "startpanel.proglist",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "mfuBorder",
        "content": True,
        "content_prefix": "mfuContent",
        "text_color": True,
        "text_color_key": "mfuText",
        "hot_tracking": True,
        "hot_tracking_key": "mfuHot",
        "fill_hint_key": "mfuFill",
    },
    {
        "section": "startpanel.placeslist",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "placesBorder",
        "content": True,
        "content_prefix": "placesContent",
        "text_color": True,
        "text_color_key": "placesText",
        "hot_tracking": True,
        "hot_tracking_key": "placesHot",
        "fill_hint_key": "placesFill",
    },
    {
        "section": "startpanel.logoff",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "logoffBorder",
        "text_color": True,
        "text_color_key": "logoffText",
        "fill_hint_key": "logoffFill",
    },
    {
        "section": "startpanel.moreprograms",
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "moreProgBorder",
    },
    {
        "section": "startmenu::toolbar",
        "group": "startGroup",
        "sizing": True,
        "fill_hint_key": "fill",
        "accent_hint_key": "accent",
    },
    {
        "section": "window.closebutton",
        "group": "captionButton",
        "frames": "imagecount",
        "sizing": True,
        "image_layout": True,
        # Offset = x,y from OffsetType (TopRight); y is caption-button top padding.
        "offset": True,
    },
    {
        "section": "window.frameleft",
        "group": "frame",
        "frames_key": "leftFrames",
        "frames": "imagecount",
        "image_layout": True,
        "sizing_prefix": "left",
    },
    {
        "section": "window.frameright",
        "group": "frame",
        "frames_key": "rightFrames",
        "frames": "imagecount",
        "image_layout": True,
        "sizing_prefix": "right",
    },
    {
        "section": "window.framebottom",
        "group": "frame",
        "frames_key": "bottomFrames",
        "frames": "imagecount",
        "image_layout": True,
        "sizing_prefix": "bottom",
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
    "windowtext": "windowText",
    "btntext": "buttonText",
    "menutext": "menuText",
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
