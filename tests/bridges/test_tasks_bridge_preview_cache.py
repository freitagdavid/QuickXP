"""Preview cache path token rules (keep in sync with TasksBridge.safe_window_token)."""

from __future__ import annotations

import re


def safe_window_token(window_id: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", str(window_id).strip()) or "unknown"


def test_safe_window_token():
    assert safe_window_token("12345") == "12345"
    assert safe_window_token("a/b c") == "a_b_c"
    assert safe_window_token("  ") == "unknown"
    assert safe_window_token("org.kde.dolphin") == "org.kde.dolphin"
