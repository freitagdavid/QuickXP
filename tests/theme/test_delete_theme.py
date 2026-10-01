"""Tests for QuickXP/services/delete_theme.py."""

from __future__ import annotations

import json
from pathlib import Path

import delete_theme


def test_delete_theme_removes_pack(tmp_path: Path):
    root = tmp_path / "themes"
    theme = root / "concave-dark"
    theme.mkdir(parents=True)
    (theme / "theme.json").write_text('{"name":"Concave Dark"}', encoding="utf-8")
    (theme / "extra.txt").write_text("x", encoding="utf-8")

    result = delete_theme.delete_theme(root, "concave-dark")
    assert result["ok"] is True
    assert result["slug"] == "concave-dark"
    assert not theme.exists()


def test_delete_theme_rejects_missing(tmp_path: Path):
    root = tmp_path / "themes"
    root.mkdir()
    result = delete_theme.delete_theme(root, "nope")
    assert result["ok"] is False


def test_delete_theme_rejects_path_escape(tmp_path: Path):
    root = tmp_path / "themes"
    root.mkdir()
    result = delete_theme.delete_theme(root, "../outside")
    assert result["ok"] is False


def test_delete_theme_cli(tmp_path: Path):
    root = tmp_path / "themes"
    theme = root / "pack"
    theme.mkdir(parents=True)
    (theme / "theme.json").write_text("{}", encoding="utf-8")
    code = delete_theme.main(["--dest", str(root), "pack"])
    assert code == 0
    assert not theme.exists()
