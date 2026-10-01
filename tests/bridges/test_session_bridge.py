"""SessionBridge command resolution (no live power actions)."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import SessionBridge as sb  # noqa: E402


def test_command_for_logoff_prefers_session_id(monkeypatch):
    monkeypatch.setenv("XDG_SESSION_ID", "42")
    monkeypatch.setattr(sb, "which", lambda name: f"/usr/bin/{name}")
    assert sb.command_for("logoff") == ["/usr/bin/loginctl", "terminate-session", "42"]


def test_command_for_logoff_falls_back_to_user(monkeypatch):
    monkeypatch.delenv("XDG_SESSION_ID", raising=False)
    monkeypatch.setenv("USER", "dave")
    monkeypatch.setattr(sb, "which", lambda name: f"/bin/{name}")
    assert sb.command_for("logoff") == ["/bin/loginctl", "terminate-user", "dave"]


def test_command_for_power_actions(monkeypatch):
    monkeypatch.setattr(sb, "which", lambda name: f"/usr/bin/{name}")
    assert sb.command_for("poweroff") == ["/usr/bin/systemctl", "poweroff"]
    assert sb.command_for("reboot") == ["/usr/bin/systemctl", "reboot"]
    assert sb.command_for("suspend") == ["/usr/bin/systemctl", "suspend"]


def test_command_for_missing_tools(monkeypatch):
    monkeypatch.setattr(sb, "which", lambda name: None)
    assert sb.command_for("logoff") is None
    assert sb.command_for("poweroff") is None
    assert sb.can("poweroff") is False


def test_unknown_action():
    assert sb.command_for("hibernate") is None
