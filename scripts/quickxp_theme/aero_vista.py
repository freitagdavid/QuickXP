"""Vista Aero class/part bindings onto QuickXP logical theme keys.

Part ids are the vsstyle.h values (BUTTON, WINDOW, TASKBAR, STARTPANEL, …).
Windows 7 reuses this table's shape in aero_win7.py; it does not reuse these parts.
"""

from __future__ import annotations

# Each binding:
#   classes: preferred class names (composited glass first when it has art)
#   part: vsstyle part id
#   images: [(logical_key, field)] field is imagefile / imagefile1 / glyphimagefile / imagefile3
#   group: theme.json group name
#   frames / sizing / content / layout / sizing_type / text_color / fill_hint / offset
#   disabled_state: state id whose TEXTCOLOR becomes disabledText

BINDINGS: list[dict] = [
    {
        "classes": ["Button"],
        "part": 1,  # BP_PUSHBUTTON
        "images": [("buttonImage", "imagefile")],
        "group": "button",
        "frames": True,
        "sizing": True,
        "layout": True,
        "sizing_type": True,
        "disabled_state": 4,
    },
    {
        "classes": ["Button"],
        "part": 3,  # BP_CHECKBOX
        "images": [("checkBoxImage", "imagefile1")],
        "group": "checkBox",
        "frames": True,
    },
    {
        "classes": ["Button"],
        "part": 2,  # BP_RADIOBUTTON
        "images": [("radioButtonImage", "imagefile1")],
        "group": "radioButton",
        "frames": True,
    },
    {
        "classes": ["Button"],
        "part": 4,  # BP_GROUPBOX
        "images": [("groupBoxImage", "imagefile")],
        "group": "groupBox",
    },
    {
        "classes": ["Combobox"],
        "part": 1,  # CP_DROPDOWNBUTTON
        "images": [
            ("comboButtonImage", "imagefile"),
            ("comboButtonGlyphImage", "glyphimagefile"),
        ],
        "group": "combo",
        "frames": True,
        "sizing": True,
    },
    {
        "classes": ["ScrollBar"],
        "part": 1,  # SBP_ARROWBTN
        "images": [("scrollArrowImage", "imagefile")],
        "group": "scrollBar",
        "frames": True,
        "frames_key": "arrowFrames",
        "sizing": True,
    },
    {
        "classes": ["ScrollBar"],
        "part": 3,  # SBP_THUMBBTNVERT
        "images": [("scrollThumbVerticalImage", "imagefile")],
        "group": "scrollBar",
        "frames": True,
        "frames_key": "thumbFrames",
        "sizing_prefix": "thumb",
    },
    {
        "classes": ["ScrollBar"],
        "part": 6,  # SBP_LOWERTRACKVERT
        "images": [("scrollShaftVerticalImage", "imagefile")],
        "group": "scrollBar",
        "frames": True,
        "frames_key": "shaftFrames",
    },
    {
        "classes": ["Spin"],
        "part": 1,  # SPNP_UP
        "images": [
            ("spinUpBackgroundImage", "imagefile"),
            ("spinUpGlyphImage", "glyphimagefile"),
        ],
        "group": "spin",
        "frames": True,
        "sizing": True,
    },
    {
        "classes": ["Spin"],
        "part": 2,  # SPNP_DOWN
        "images": [
            ("spinDownBackgroundImage", "imagefile"),
            ("spinDownGlyphImage", "glyphimagefile"),
        ],
        "group": "spin",
    },
    {
        "classes": ["Tab"],
        "part": 5,  # TABP_TOPTABITEM
        "images": [("tabItemTopImage", "imagefile")],
        "group": "tab",
        "frames": True,
        "sizing": True,
    },
    {
        "classes": ["Tab"],
        "part": 9,  # TABP_PANE
        "images": [("tabPaneEdgeImage", "imagefile")],
    },
    {
        "classes": ["Tab"],
        "part": 10,  # TABP_BODY
        "images": [("tabBackgroundImage", "imagefile1")],
        "group": "tab",
        "fill_hint": "bodyFill",
    },
    {
        "classes": ["Tooltip"],
        "part": 5,  # TTP_CLOSE
        "images": [
            ("tooltipCloseImage", "imagefile1"),
            ("previewCloseImage", "imagefile1"),
        ],
    },
    {
        "classes": ["TaskBarComposited::TaskBar", "TaskBar"],
        "part": 1,  # TBP_BACKGROUNDBOTTOM
        "images": [("taskbarImage", "imagefile")],
        "group": "taskbar",
        "sizing": True,
        "fill_hint": "fill",
    },
    {
        "classes": ["TaskBandComposited::Toolbar", "TaskBand::Toolbar"],
        "part": 1,
        "images": [("taskButtonImage", "imagefile")],
        "group": "taskButton",
        "frames": True,
        "sizing": True,
        "layout": True,
    },
    {
        "classes": ["TaskBandComposited::ScrollBar", "TaskBand::ScrollBar"],
        "part": 1,
        "images": [
            ("taskScrollArrowImage", "imagefile"),
            ("taskScrollArrowGlyphImage", "glyphimagefile"),
        ],
    },
    {
        "classes": ["TrayNotifyHorizComposited::TrayNotify", "TrayNotifyHoriz::TrayNotify"],
        "part": 1,  # TNP_BACKGROUND
        "images": [("trayImage", "imagefile")],
        "group": "tray",
        "sizing": True,
    },
    {
        "classes": ["TrayNotifyHorizComposited::Button", "TrayNotifyHoriz::Button"],
        "part": 0,
        "images": [("trayChevronImage", "imagefile1")],
        "frames": True,
    },
    {
        "classes": ["TrayNotifyHorizOpenComposited::Button", "TrayNotifyHorizOpen::Button"],
        "part": 0,
        "images": [("trayChevronOpenImage", "imagefile1")],
    },
    {
        "classes": ["Window"],
        "part": 1,  # WP_CAPTION
        "images": [("captionImage", "imagefile")],
        "group": "caption",
        "frames": True,
        "sizing": True,
        "content": True,
        "layout": True,
        "sizing_type": True,
    },
    {
        "classes": ["Window"],
        "part": 30,  # WP_CAPTIONSIZINGTEMPLATE
        "images": [("captionSizingTemplateImage", "imagefile")],
        "group": "caption",
        "content": True,
        "content_prefix": "templateContent",
    },
    {
        "classes": ["Window"],
        "part": 7,  # WP_FRAMELEFT
        "images": [("frameLeftImage", "imagefile")],
        "group": "frame",
        "frames": True,
        "frames_key": "leftFrames",
        "sizing_prefix": "left",
        "layout": True,
    },
    {
        "classes": ["Window"],
        "part": 8,  # WP_FRAMERIGHT
        "images": [("frameRightImage", "imagefile")],
        "group": "frame",
        "frames": True,
        "frames_key": "rightFrames",
        "sizing_prefix": "right",
    },
    {
        "classes": ["Window"],
        "part": 9,  # WP_FRAMEBOTTOM
        "images": [("frameBottomImage", "imagefile")],
        "group": "frame",
        "frames": True,
        "frames_key": "bottomFrames",
        "sizing_prefix": "bottom",
    },
    {
        "classes": ["Window"],
        "part": 18,  # WP_CLOSEBUTTON
        "images": [
            ("closeButtonImage", "imagefile"),
            ("closeGlyphImage", "imagefile3"),
        ],
        "group": "captionButton",
        "frames": True,
        "sizing": True,
        "layout": True,
        "offset": True,
    },
    {
        "classes": ["Window"],
        "part": 15,  # WP_MINBUTTON
        "images": [
            ("minButtonImage", "imagefile"),
            ("minGlyphImage", "imagefile3"),
        ],
    },
    {
        "classes": ["Window"],
        "part": 17,  # WP_MAXBUTTON
        "images": [
            ("maxButtonImage", "imagefile"),
            ("maxGlyphImage", "imagefile3"),
        ],
    },
    {
        "classes": ["Window"],
        "part": 21,  # WP_RESTOREBUTTON
        "images": [
            ("restoreButtonImage", "imagefile"),
            ("restoreGlyphImage", "imagefile3"),
        ],
    },
    {
        "classes": ["Window"],
        "part": 23,  # WP_HELPBUTTON
        "images": [
            ("helpButtonImage", "imagefile"),
            ("helpGlyphImage", "imagefile3"),
        ],
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 1,  # SPP_USERPANE
        "images": [("startUserPanelImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "userBorder",
        "text_color": "userNameColor",
        "fill_hint": "userFill",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 10,  # SPP_USERPICTURE
        "images": [("startUserTileImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "tileBorder",
        "content": True,
        "content_prefix": "tileContent",
        "fill_hint": "tileFill",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 4,  # SPP_PROGLIST
        "images": [("startPanelMfuBackgroundImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "mfuBorder",
        "content": True,
        "content_prefix": "mfuContent",
        "text_color": "mfuText",
        "fill_hint": "mfuFill",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 5,
        "images": [("startPanelProgramsSeparatorImage", "imagefile")],
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 2,  # SPP_MOREPROGRAMS
        "images": [("startPanelMoreProgBackgroundImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "moreProgBorder",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 3,  # SPP_MOREPROGRAMSARROW
        "images": [("startPanelMoreProgArrowImage", "imagefile")],
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 6,  # SPP_PLACESLIST
        "images": [("startPanelPlacesBackgroundImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "placesBorder",
        "content": True,
        "content_prefix": "placesContent",
        "text_color": "placesText",
        "fill_hint": "placesFill",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 7,
        "images": [("startPanelPlacesSeparatorImage", "imagefile")],
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 8,  # SPP_LOGOFF
        "images": [("startPanelLogoffBackgroundImage", "imagefile")],
        "group": "startPanel",
        "sizing": True,
        "sizing_prefix": "logoffBorder",
        "text_color": "logoffText",
        "fill_hint": "logoffFill",
    },
    {
        "classes": ["StartPanelComposited::StartPanel", "StartPanel"],
        "part": 9,  # SPP_LOGOFFBUTTONS
        "images": [("startPanelLogoffButtonsImage", "imagefile")],
    },
    {
        "classes": ["StartMenu::Toolbar"],
        "part": 0,
        "images": [("startGroupBackgroundImage", "imagefile")],
        "group": "startGroup",
        "sizing": True,
        "fill_hint": "fill",
    },
]

# Vista draws the Start pearl as one state strip. Middle is the body;
# Top/Bottom are the same control split on some builds. The projector
# uses the first class that actually has an image.
START_BUTTON_CLASSES = [
    "StartMiddle::Button",
    "StartTop::Button",
    "StartBottom::Button",
    "Start::Button",
]

# SysMetrics color property -> theme.colors key.
SYS_COLORS = {
    "BACKGROUND": "desktop",
    "BTNFACE": "button",
    "WINDOW": "window",
    "WINDOWTEXT": "windowText",
    "BTNTEXT": "buttonText",
    "MENUTEXT": "menuText",
    "MENU": "menu",
    "HIGHLIGHT": "highlight",
    "HIGHLIGHTTEXT": "highlightText",
    "ACTIVECAPTION": "titleActive",
    "CAPTIONTEXT": "titleActiveText",
    "INACTIVECAPTION": "titleInactive",
    "INACTIVECAPTIONTEXT": "titleInactiveText",
}

# DWMWindow part ids. Sizes and pixels come from the loaded atlas; this table
# only names which part plays which role. Lists are DPI sets, smallest first.
DWM_ROLES: dict[str, int | list[int]] = {
    "reflection": 40,
    "captionHighlightActive": 34,
    "captionHighlightInactive": 42,
    "titleGlow": 56,
    "buttonBgActive": 3,
    "buttonBgInactive": 4,
    "buttonBgActiveAlt": 5,
    "buttonBgInactiveAlt": 6,
    "closeBgActive": 7,
    "closeBgInactive": 8,
    "closeBgActiveAlt": 9,
    "closeBgInactiveAlt": 10,
    "closeGlyphs": [12, 13, 14, 15],
    "helpGlyphs": [17, 18, 19, 20],
    "maxGlyphs": [21, 22, 23, 24],
    "minGlyphs": [25, 26, 27, 28],
    "restoreGlyphs": [29, 30, 31, 32],
    "outlineTopLeft": 39,
    "outlineTopRight": 57,
    "outlineBottomLeft": 1,
    "outlineBottomRight": 36,
    "outlineLeft": 35,
    "outlineRight": 43,
    "outlineTop": 33,
    "outlineBottom": 37,
    "outlineTopAlt": 38,
    "outlineBottomAlt": 41,
}

EDGE_COLORS = (
    ("EDGESHADOWCOLOR", "edgeShadow"),
    ("EDGEHIGHLIGHTCOLOR", "edgeHighlight"),
    ("EDGELIGHTCOLOR", "edgeLight"),
    ("EDGEDKSHADOWCOLOR", "edgeDkShadow"),
)
