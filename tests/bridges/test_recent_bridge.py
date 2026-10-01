"""RecentBridge xbel / bookmarks helpers."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import RecentBridge as rb  # noqa: E402


def test_label_from_uri():
    assert rb.label_from_uri("file:///home/dave/Docs/a%20b.pdf") == "a b.pdf"


def test_list_recent_from_fixture(tmp_path, monkeypatch):
    xbel = tmp_path / "recently-used.xbel"
    xbel.write_text(
        """<?xml version="1.0"?>
<xbel version="1.0">
  <bookmark href="file:///tmp/one.txt"/>
  <bookmark href="file:///tmp/two.txt"/>
  <bookmark href="https://example.com"/>
</xbel>
""",
        encoding="utf-8",
    )
    monkeypatch.setattr(rb, "recent_path", lambda: xbel)
    items = rb.list_recent(10)
    assert [i["label"] for i in items] == ["one.txt", "two.txt"]
    assert items[0]["action"] == "open-uri"


def test_list_favorites(tmp_path, monkeypatch):
    bookmarks = tmp_path / "bookmarks"
    bookmarks.write_text(
        "file:///home/dave/Documents Documents\nfile:///home/dave/Music\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(rb, "bookmarks_path", lambda: bookmarks)
    items = rb.list_favorites()
    assert len(items) == 2
    assert items[0]["label"] == "Documents"


def test_clear_recent(tmp_path, monkeypatch):
    xbel = tmp_path / "recently-used.xbel"
    xbel.write_text("<xbel></xbel>", encoding="utf-8")
    monkeypatch.setattr(rb, "recent_path", lambda: xbel)
    assert rb.clear_recent()["ok"] is True
    assert "xbel" in xbel.read_text(encoding="utf-8")
