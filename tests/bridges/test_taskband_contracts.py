"""Architecture contracts for taskband / TasksBridge ownership (no live KWin)."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUICKXP = ROOT / "QuickXP"


def _qml_files() -> list[Path]:
    return sorted(QUICKXP.rglob("*.qml"))


def test_tasks_bridge_process_only_in_tasks_service():
    offenders = []
    for path in _qml_files():
        if "TasksBridge.py" in path.read_text(encoding="utf-8"):
            if path.name != "TasksService.qml":
                offenders.append(str(path.relative_to(ROOT)))
    assert offenders == [], f"TasksBridge.py must only appear in TasksService.qml: {offenders}"


def test_shell_keeps_tasks_service_alive():
    text = (QUICKXP / "Shell.qml").read_text(encoding="utf-8")
    assert "TasksService" in text
    assert "tasksService" in text


def test_tasklist_delegates_commands_to_tasks_service():
    text = (QUICKXP / "taskbar" / "TaskList.qml").read_text(encoding="utf-8")
    assert "TasksService.sendCommand" in text
    assert "TasksService.requestPreview" in text


def test_no_process_in_taskbar_qml():
    offenders = []
    for path in (QUICKXP / "taskbar").rglob("*.qml"):
        if re.search(r"\bProcess\s*\{", path.read_text(encoding="utf-8")):
            offenders.append(str(path.relative_to(ROOT)))
    assert offenders == [], f"taskbar QML must not own Process: {offenders}"


def test_tasks_service_stdin_enabled_before_running():
    text = (QUICKXP / "TasksService.qml").read_text(encoding="utf-8")
    # Narrow to the bridge Process block.
    match = re.search(r"Process\s*\{(.*?)onStarted:", text, re.DOTALL)
    assert match, "TasksService Process block not found"
    block = match.group(1)
    stdin_at = block.find("stdinEnabled:")
    running_at = block.find("running:")
    assert stdin_at >= 0, "stdinEnabled missing on TasksService Process"
    assert running_at >= 0, "running missing on TasksService Process"
    assert stdin_at < running_at, "stdinEnabled must be set before running"


def test_taskbar_variants_are_per_screen():
    text = (QUICKXP / "Shell.qml").read_text(encoding="utf-8")
    assert "Quickshell.screens" in text
    assert "TaskBar" in text
    assert re.search(r"Variants\s*\{[^}]*Quickshell\.screens", text, re.DOTALL)
