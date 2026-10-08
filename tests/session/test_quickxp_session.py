"""Bare KWin + Quickshell session does not launch Plasma."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "session" / "quickxp-session"
DESKTOP = ROOT / "session" / "quickxp.desktop"
INSTALL = ROOT / "scripts" / "install-session.sh"

FORBIDDEN = (
    "startplasma",
    "plasmashell",
    "kded",
    "powerdevil",
    "kscreenlocker",
)


def _desktop_fields() -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in DESKTOP.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or line.startswith("["):
            continue
        key, _, value = line.partition("=")
        fields[key.strip()] = value.strip()
    return fields


def test_session_script_is_kwin_and_quickshell_only():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "kwin_wayland" in text
    assert "--exit-with-session" in text
    assert "--no-lockscreen" in text
    assert "--no-kactivities" in text
    assert "--drm" in text
    assert "--xwayland" in text
    assert "XDG_CURRENT_DESKTOP=QuickXP" in text
    assert "KDE_FULL_SESSION" not in text
    assert "XDG_CURRENT_DESKTOP=KDE" not in text
    assert "--no-global-shortcuts" not in text
    for name in FORBIDDEN:
        assert name not in text


def test_desktop_entry_points_at_session_script():
    fields = _desktop_fields()
    assert fields["Type"] == "Application"
    assert fields["Name"] == "QuickXP"
    assert fields["DesktopNames"] == "QuickXP"
    assert fields["Exec"] == "quickxp-session"
    assert fields["TryExec"] == "quickxp-session"


def test_install_script_targets_sddm_wayland_sessions():
    text = INSTALL.read_text(encoding="utf-8")
    assert "/usr/share/wayland-sessions" in text
    assert "quickxp-session" in text
    assert "Exec=${bindir}/quickxp-session" in text
