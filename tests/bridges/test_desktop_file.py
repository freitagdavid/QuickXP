"""DesktopFile locate / Exec parse / user override save."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "QuickXP" / "services"))
import DesktopFile as df  # noqa: E402


SAMPLE = """[Desktop Entry]
Type=Application
Name=Firefox
Comment=Web Browser
Exec=firefox %u
Icon=firefox
Path=/tmp
Terminal=false
Categories=Network;
"""


def test_desktop_filename_adds_suffix_and_rejects_paths():
    assert df.desktop_filename("firefox") == "firefox.desktop"
    assert df.desktop_filename("firefox.desktop") == "firefox.desktop"
    with pytest.raises(ValueError):
        df.desktop_filename("../firefox")
    with pytest.raises(ValueError):
        df.desktop_filename("kde/kate.desktop")


def test_exec_binary_token_skips_field_codes_and_quotes():
    assert df.exec_binary_token("firefox %u") == "firefox"
    assert df.exec_binary_token('"/opt/My App/bin" %f') == "/opt/My App/bin"
    assert df.exec_binary_token("%c %k my-app") == "my-app"
    assert df.exec_binary_token("") == ""


def test_resolve_binary_absolute_and_path(tmp_path):
    binary = tmp_path / "bin" / "firefox"
    binary.parent.mkdir()
    binary.write_text("#!/bin/sh\n")
    exists = lambda p: Path(p).is_file()
    assert df.resolve_binary(str(binary), path_env="", exists=exists) == str(binary)
    assert (
        df.resolve_binary(
            "firefox",
            path_env=f"{tmp_path / 'empty'}:{binary.parent}",
            exists=lambda p: Path(p).is_file(),
        )
        == str(binary)
    )
    assert df.resolve_binary("missing", path_env=str(binary.parent), exists=lambda p: Path(p).is_file()) == ""


def test_find_prefers_user_then_vendor_subdir(tmp_path):
    home = tmp_path / "home"
    system = tmp_path / "usr"
    (home / "applications").mkdir(parents=True)
    vendor = system / "applications" / "kde"
    vendor.mkdir(parents=True)
    user_file = home / "applications" / "kate.desktop"
    user_file.write_text(SAMPLE)
    (vendor / "kate.desktop").write_text("system")
    (vendor / "only-vendor.desktop").write_text("vendor")
    assert df.find_desktop_file("kate.desktop", str(home), [str(system)]) == user_file
    found = df.find_desktop_file("only-vendor.desktop", str(home), [str(system)])
    assert found == system / "applications" / "kde" / "only-vendor.desktop"


def test_read_and_apply_fields_preserve_other_keys():
    fields = df.read_desktop_fields(SAMPLE)
    assert fields["name"] == "Firefox"
    assert fields["exec"] == "firefox %u"
    assert fields["workingDirectory"] == "/tmp"
    assert fields["terminal"] is False
    updated = df.apply_fields(
        SAMPLE,
        {
            "Name": "Nightly",
            "Comment": "Line\nbreak",
            "Exec": "/usr/bin/nightly",
            "Icon": "nightly",
            "Path": "",
            "Terminal": "true",
        },
    )
    again = df.read_desktop_fields(updated)
    assert again["name"] == "Nightly"
    assert again["comment"] == "Line\nbreak"
    assert again["exec"] == "/usr/bin/nightly"
    assert again["terminal"] is True
    assert "Categories=Network;" in updated


def test_save_writes_user_override_and_leaves_system(tmp_path):
    home = tmp_path / "data"
    system = tmp_path / "usr" / "share"
    apps = system / "applications"
    apps.mkdir(parents=True)
    system_file = apps / "firefox.desktop"
    system_file.write_text(SAMPLE)
    env = {
        "HOME": str(tmp_path),
        "XDG_DATA_HOME": str(home),
        "XDG_DATA_DIRS": str(system),
        "PATH": "",
    }
    saved = df.save_entry(
        "firefox",
        {
            "name": "Firefox Nightly",
            "comment": "Test",
            "exec": "/opt/firefox/firefox",
            "icon": "firefox-nightly",
            "workingDirectory": "/opt/firefox",
            "terminal": False,
        },
        env=env,
    )
    assert saved["ok"] is True
    dest = Path(saved["path"])
    assert dest == home / "applications" / "firefox.desktop"
    assert system_file.read_text() == SAMPLE
    text = dest.read_text()
    assert "Name=Firefox Nightly" in text
    assert "Exec=/opt/firefox/firefox" in text
    assert "Categories=Network;" in text
    located = df.locate_entry("firefox.desktop", env=env, exists=lambda _p: False)
    assert located["ok"] is True
    assert located["desktopPath"] == str(dest)
    assert located["binaryExists"] is False
    assert located["name"] == "Firefox Nightly"


def test_cli_locate_and_save(tmp_path, monkeypatch, capsys):
    home = tmp_path / "data"
    system = tmp_path / "usr"
    (system / "applications").mkdir(parents=True)
    binary = tmp_path / "bin" / "demo"
    binary.parent.mkdir()
    binary.write_text("")
    (system / "applications" / "demo.desktop").write_text(
        "[Desktop Entry]\nType=Application\nName=Demo\nExec=demo\n"
    )
    monkeypatch.setenv("XDG_DATA_HOME", str(home))
    monkeypatch.setenv("XDG_DATA_DIRS", str(system))
    monkeypatch.setenv("PATH", str(binary.parent))
    assert df.main(["locate", "demo", "7"]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["binary"] == str(binary)
    assert payload["token"] == "7"
    assert df.main([
        "save",
        "demo",
        json.dumps({"name": "Demo 2", "exec": "demo", "terminal": True}),
    ]) == 0
    capsys.readouterr()
    text = (home / "applications" / "demo.desktop").read_text()
    assert "Name=Demo 2" in text
    assert "Terminal=true" in text
