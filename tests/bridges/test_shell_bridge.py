"""ShellBridge Meta / desktop helpers (no live DBus required)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import ShellBridge as sb  # noqa: E402


def test_constants():
    assert sb.DESKTOP_ID == "org.quickxp.start.desktop"
    assert sb.META_KEY == 16777250
    assert sb.META_SPACE == 268435488
    assert sb.PLASMA_LAUNCHER_ALT_F1 == 150994992
    assert [sb.META_KEY, 0, 0, 0] in sb.START_SHORTCUT_KEYS
    assert [sb.META_SPACE, 0, 0, 0] in sb.START_SHORTCUT_KEYS


def test_write_desktop_files(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(sb.subprocess, "run", lambda *a, **k: None)
    monkeypatch.setattr(
        sb.shutil,
        "which",
        lambda name: "/usr/bin/qdbus6" if name == "qdbus6" else None,
    )
    sb.write_desktop_files()
    app = tmp_path / ".local/share/applications" / sb.DESKTOP_ID
    accel = tmp_path / ".local/share/kglobalaccel" / sb.DESKTOP_ID
    assert app.is_file()
    assert accel.is_file()
    text = app.read_text(encoding="utf-8")
    assert "org.quickxp.Shell" in text
    assert "ToggleStart" in text
    assert "Exec=/usr/bin/qdbus6" in text
    assert text == accel.read_text(encoding="utf-8")


def test_clear_legacy_kwinrc_meta(monkeypatch):
    deleted = []

    monkeypatch.setattr(sb, "kreadconfig", lambda *a: sb.LEGACY_META_BINDING)
    monkeypatch.setattr(
        sb,
        "kwriteconfig",
        lambda *a: deleted.append(a) or True,
    )
    sb.clear_legacy_kwinrc_meta()
    assert deleted
    assert "--delete" in deleted[0]


def test_cmdline_is_shell_bridge():
    assert sb._cmdline_is_shell_bridge(
        ["/usr/bin/python3", "/home/x/.config/quickshell/default/QuickXP/services/ShellBridge.py"]
    )
    assert not sb._cmdline_is_shell_bridge(["zsh", "-c", "pkill ShellBridge.py; true"])
    assert not sb._cmdline_is_shell_bridge(["/usr/bin/python3", "/tmp/other.py"])


def test_stale_bridge_pids(tmp_path):
    def write_proc(pid: int, parts: list[str]) -> None:
        d = tmp_path / str(pid)
        d.mkdir()
        (d / "cmdline").write_bytes(b"\0".join(p.encode() for p in parts) + b"\0")

    write_proc(10, ["/usr/bin/python3", "/tmp/ShellBridge.py"])
    write_proc(11, ["/usr/bin/python3", "/tmp/other.py"])
    write_proc(12, ["zsh", "-c", "echo ShellBridge.py"])
    assert sb.stale_bridge_pids(tmp_path, self_pid=99) == [10]
    assert sb.stale_bridge_pids(tmp_path, self_pid=10) == []
