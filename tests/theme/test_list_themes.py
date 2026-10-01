"""Tests for QuickXP/services/list_themes.py."""

from __future__ import annotations

from pathlib import Path

import list_themes


def test_scan_installed_themes(themes_root: Path):
    themes = list_themes.scan(themes_root)
    by_slug = {t["slug"]: t for t in themes}
    assert "luna" in by_slug
    luna = by_slug["luna"]
    assert luna["name"]
    assert luna["generation"] in ("xp", "vista", "win7", "classic", "")
    assert Path(luna["path"]).name == "luna"
    assert isinstance(luna["images"], dict)

    if "aero" in by_slug:
        assert by_slug["aero"]["slug"] == "aero"


def test_scan_missing_root(tmp_path: Path):
    assert list_themes.scan(tmp_path / "nope") == []


def test_scan_skips_dirs_without_theme_json(tmp_path: Path):
    (tmp_path / "empty").mkdir()
    (tmp_path / "partial").mkdir()
    (tmp_path / "partial" / "readme.txt").write_text("nope", encoding="utf-8")
    good = tmp_path / "good"
    good.mkdir()
    (good / "theme.json").write_text(
        '{"name":"Good","generation":"xp","images":{}}',
        encoding="utf-8",
    )
    themes = list_themes.scan(tmp_path)
    assert len(themes) == 1
    assert themes[0]["slug"] == "good"
    assert themes[0]["name"] == "Good"
    assert themes[0]["generation"] == "xp"
