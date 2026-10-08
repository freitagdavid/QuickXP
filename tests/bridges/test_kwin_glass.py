"""KWin glass follows the applied theme generation (no live KWin session)."""

from __future__ import annotations

import json

import sync_aurorae


def test_theme_wants_glass_reads_generation(tmp_path):
    root = tmp_path / "aero"
    root.mkdir()
    (root / "theme.json").write_text(json.dumps({"generation": "vista"}), encoding="utf-8")
    assert sync_aurorae.theme_wants_glass(root) is True

    (root / "theme.json").write_text(json.dumps({"generation": "win7"}), encoding="utf-8")
    assert sync_aurorae.theme_wants_glass(root) is True

    (root / "theme.json").write_text(json.dumps({"generation": "xp"}), encoding="utf-8")
    assert sync_aurorae.theme_wants_glass(root) is False

    assert sync_aurorae.theme_wants_glass(tmp_path / "missing") is False


def _package(root, generation: str, *, qml: bool) -> None:
    root.mkdir()
    (root / "theme.json").write_text(json.dumps({"generation": generation}), encoding="utf-8")
    aurorae = root / "aurorae"
    aurorae.mkdir()
    (aurorae / "metadata.desktop").write_text(
        "[Desktop Entry]\nX-KDE-PluginInfo-Name=quickxp-sample\n",
        encoding="utf-8",
    )
    if qml:
        package = root / "kdecoration"
        package.mkdir()
        (package / "metadata.json").write_text(
            json.dumps({"KPlugin": {"Id": "kwin4_decoration_qml_quickxp_sample"}}),
            encoding="utf-8",
        )


def test_vista_and_win7_select_qml_xp_selects_aurorae(tmp_path):
    vista = tmp_path / "vista"
    _package(vista, "vista", qml=True)
    choice = sync_aurorae.preferred_decoration(vista)
    assert choice["qml"] is True
    assert choice["id"] == "kwin4_decoration_qml_quickxp_sample"
    steps = sync_aurorae.decoration_config_argv("kwriteconfig6", choice["id"], qml=True)
    assert steps[1][-1] == "kwin4_decoration_qml_quickxp_sample"
    assert "__aurorae__svg__" not in steps[1][-1]

    win7 = tmp_path / "win7"
    _package(win7, "win7", qml=True)
    assert sync_aurorae.preferred_decoration(win7)["qml"] is True

    xp = tmp_path / "xp"
    _package(xp, "xp", qml=True)
    xp_choice = sync_aurorae.preferred_decoration(xp)
    assert xp_choice["qml"] is False
    assert xp_choice["id"] == "quickxp-sample"
    xp_steps = sync_aurorae.decoration_config_argv("kwriteconfig6", xp_choice["id"], qml=False)
    assert xp_steps[1][-1] == "__aurorae__svg__quickxp-sample"


def test_kwin_glass_argv_toggles_blur_and_contrast():
    on = sync_aurorae.kwin_glass_argv("kwriteconfig6", True)
    assert on == [
        ["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "blurEnabled", "true"],
        ["kwriteconfig6", "--file", "kwinrc", "--group", "Plugins", "--key", "contrastEnabled", "true"],
    ]
    off = sync_aurorae.kwin_glass_argv("kwriteconfig6", False)
    assert off[0][-1] == "false"
    assert off[1][-1] == "false"
