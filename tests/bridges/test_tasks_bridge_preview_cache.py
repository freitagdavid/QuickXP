"""Preview cache path token rules (TasksBridge.safe_window_token)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import TasksBridge as tb  # noqa: E402


def test_safe_window_token():
    assert tb.safe_window_token("12345") == "12345"
    assert tb.safe_window_token("a/b c") == "a_b_c"
    assert tb.safe_window_token("  ") == "unknown"
    assert tb.safe_window_token("org.kde.dolphin") == "org.kde.dolphin"
