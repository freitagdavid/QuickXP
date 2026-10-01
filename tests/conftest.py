"""Shared fixtures for QuickXP pytest suite."""

from __future__ import annotations

import pathlib

import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]


@pytest.fixture
def repo_root() -> pathlib.Path:
    return REPO_ROOT


@pytest.fixture
def luna_theme(repo_root: pathlib.Path) -> pathlib.Path:
    path = repo_root / "QuickXP" / "themes" / "luna"
    assert path.is_dir(), f"missing Luna theme fixture at {path}"
    return path


@pytest.fixture
def themes_root(repo_root: pathlib.Path) -> pathlib.Path:
    path = repo_root / "QuickXP" / "themes"
    assert path.is_dir(), f"missing themes root at {path}"
    return path
