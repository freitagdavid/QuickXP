"""MenuBridge Programs tree builders."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
BRIDGE = ROOT / "QuickXP" / "services" / "MenuBridge.py"
FIXTURE_MENU = Path(__file__).parent / "fixtures" / "menus" / "simple.menu"

# Ensure the bridge module is importable.
sys.path.insert(0, str(BRIDGE.parent))
import MenuBridge as mb  # noqa: E402


APPS = [
    {
        "id": "firefox",
        "name": "Firefox",
        "icon": "firefox",
        "categories": ["Network", "WebBrowser"],
        "noDisplay": False,
    },
    {
        "id": "htop",
        "name": "Htop",
        "icon": "htop",
        "categories": ["System", "Utility"],
        "noDisplay": False,
    },
    {
        "id": "fixed",
        "name": "Fixed Tool",
        "icon": "fixed",
        "categories": ["Office"],
        "noDisplay": False,
    },
    {
        "id": "hidden",
        "name": "Hidden",
        "icon": "x",
        "categories": ["Utility"],
        "noDisplay": True,
    },
]


def test_desktop_id_strips_suffix():
    assert mb.desktop_id("foo.desktop") == "foo"
    assert mb.desktop_id("foo") == "foo"


def test_desktop_entry_id_from_filename():
    class FakeDesktop:
        filename = "/usr/share/applications/firefox.desktop"

        def getNoDisplay(self):
            return False

    assert mb.desktop_entry_id(FakeDesktop()) == "firefox"


def test_build_category_tree_buckets():
    tree = mb.build_category_tree(APPS)
    assert tree["kind"] == "folder"
    assert tree["label"] == "Programs"
    labels = {c["label"] for c in tree["children"]}
    assert "Internet" in labels or "Network" in labels or any(
        "Firefox" in [a["label"] for a in c["children"]] for c in tree["children"]
    )
    # Hidden excluded
    flat = []
    for folder in tree["children"]:
        flat.extend(a["label"] for a in folder["children"])
    assert "Hidden" not in flat
    assert "Firefox" in flat


def test_build_xdg_tree_from_xml_fixture():
    tree = mb.build_xdg_tree_from_xml(FIXTURE_MENU, APPS)
    assert tree["label"] == "Programs"
    by_name = {c["label"]: c for c in tree["children"]}
    assert "Internet" in by_name
    assert "Accessories" in by_name
    net_labels = {a["label"] for a in by_name["Internet"]["children"]}
    assert "Firefox" in net_labels
    acc_labels = {a["label"] for a in by_name["Accessories"]["children"]}
    assert "Htop" in acc_labels
    assert "Fixed Tool" in acc_labels


def test_cli_categories(tmp_path: Path):
    apps_path = tmp_path / "apps.json"
    apps_path.write_text(json.dumps(APPS), encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(BRIDGE), "categories", "--apps-json", str(apps_path)],
        check=True,
        capture_output=True,
        text=True,
    )
    tree = json.loads(proc.stdout)
    assert tree["label"] == "Programs"
    assert tree["children"]


def test_cli_xdg_xml(tmp_path: Path):
    apps_path = tmp_path / "apps.json"
    apps_path.write_text(json.dumps(APPS), encoding="utf-8")
    proc = subprocess.run(
        [
            sys.executable,
            str(BRIDGE),
            "xdg",
            "--menu",
            str(FIXTURE_MENU),
            "--apps-json",
            str(apps_path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    tree = json.loads(proc.stdout)
    labels = {c["label"] for c in tree["children"]}
    assert "Internet" in labels
