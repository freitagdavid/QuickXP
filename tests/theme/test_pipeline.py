"""Import pipeline + scheme listing tests (#27/#29/#30)."""

from __future__ import annotations

import json
from pathlib import Path

from quickxp_theme import pipeline
from quickxp_theme.convert import resource_name


def _tiny_png() -> bytes:
    return (
        b"\x89PNG\r\n\x1a\n"
        b"\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89"
        b"\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    )


def _write_min_extract(root: Path) -> None:
    settings = root / "settings"
    images = root / "images"
    settings.mkdir(parents=True)
    images.mkdir(parents=True)
    (settings / "NORMALBLUE.ini").write_text(
        """
[SysMetrics]
Btnface = 236 233 216
Background = 58 110 165
Highlight = 49 106 197
ActiveCaption = 0 84 227
CaptionText = 255 255 255
InactiveCaption = 122 150 223
InactiveCaptionText = 216 228 248
HighlightText = 255 255 255
Menu = 255 255 255
ScrollbarWidth = 17

[button.pushbutton]
ImageFile = Skin\\Push.bmp
SizingMargins = 4, 4, 4, 4
imageCount = 5

[TaskBar.BackgroundBottom]
ImageFile = Skin\\Bar.bmp
FillColorHint = 36 94 220

[Start::Button]
ImageFile = Skin\\Start.bmp
ContentMargins = 10, 24, 2, 4
Font = Tahoma, 12
TextColor = 255 255 255
imageCount = 3
""",
        encoding="utf-8",
    )
    (settings / "NORMALHOMESTEAD.ini").write_text(
        (settings / "NORMALBLUE.ini").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    png = _tiny_png()
    for image_file in ("Skin\\Push.bmp", "Skin\\Bar.bmp", "Skin\\Start.bmp"):
        (images / f"{resource_name(image_file)}.png").write_bytes(png)


def test_import_theme_from_extract(tmp_path: Path):
    extract = tmp_path / "src"
    _write_min_extract(extract)
    dest = tmp_path / "themes"
    result = pipeline.import_theme(extract, dest, ini="NORMALBLUE", slug="altskin")
    assert result["ok"], result
    assert result["slug"] == "altskin"
    assert result["entry"]["slug"] == "altskin"
    assert result["entry"]["path"] == result["path"]
    installed = Path(result["path"])
    assert (installed / "theme.json").is_file()
    doc = json.loads((installed / "theme.json").read_text(encoding="utf-8"))
    assert doc["images"]["buttonImage"].endswith("SKIN_PUSH_BMP.png")
    assert (installed / doc["images"]["buttonImage"]).is_file()
    assert "buttonImage" in result["entry"]["images"]
    assert result["entry"]["images"].get("startFlagImage") == "assets/start_flag.png"
    assert (installed / "assets" / "start_flag.png").is_file()
    assert doc["activeScheme"].upper() == "NORMALBLUE"
    assert "NORMALBLUE" in doc["schemeData"]
    assert "NORMALHOMESTEAD" in doc["schemeData"]
    assert len(doc["schemes"]) == 2


def test_reimport_same_source_overwrites(tmp_path: Path):
    extract = tmp_path / "src"
    _write_min_extract(extract)
    dest = tmp_path / "themes"
    first = pipeline.import_theme(extract, dest, slug="pack")
    second = pipeline.import_theme(extract, dest, slug="pack")
    assert first["ok"] and second["ok"]
    assert first["slug"] == "pack"
    assert second["slug"] == "pack"
    assert second.get("replaced") is True
    assert first["sourceHash"] and first["sourceHash"] == second["sourceHash"]
    assert list(dest.iterdir()) == [dest / "pack"]
    doc = json.loads((dest / "pack" / "theme.json").read_text(encoding="utf-8"))
    assert doc["sourceHash"] == first["sourceHash"]


def test_forced_slug_overwrites_even_if_hash_differs(tmp_path: Path):
    first_src = tmp_path / "pack-a"
    second_src = tmp_path / "pack-b"
    _write_min_extract(first_src)
    _write_min_extract(second_src)
    (second_src / "settings" / "NORMALBLUE.ini").write_text(
        (second_src / "settings" / "NORMALBLUE.ini").read_text(encoding="utf-8")
        + "\n; different\n",
        encoding="utf-8",
    )
    dest = tmp_path / "themes"
    first = pipeline.import_theme(first_src, dest, name="Pack", slug="pack")
    second = pipeline.import_theme(second_src, dest, name="Pack", slug="pack")
    assert first["ok"] and second["ok"]
    assert second["slug"] == "pack"
    assert second.get("replaced") is True
    assert first["sourceHash"] != second["sourceHash"]


def test_different_source_unforced_slug_avoids_clobber(tmp_path: Path):
    first_src = tmp_path / "Candy"
    second_src = tmp_path / "Candy2"
    _write_min_extract(first_src)
    _write_min_extract(second_src)
    (second_src / "settings" / "NORMALBLUE.ini").write_text(
        (second_src / "settings" / "NORMALBLUE.ini").read_text(encoding="utf-8")
        + "\n; other pack\n",
        encoding="utf-8",
    )
    dest = tmp_path / "themes"
    first = pipeline.import_theme(first_src, dest, name="Candy")
    second = pipeline.import_theme(second_src, dest, name="Candy")
    assert first["ok"] and second["ok"]
    assert first["slug"] == "candy"
    assert second["slug"] == "candy-2"
    assert first["sourceHash"] != second["sourceHash"]


def test_import_embeds_all_schemes_in_one_theme(tmp_path: Path):
    extract = tmp_path / "My Pack"
    _write_min_extract(extract)
    dest = tmp_path / "themes"
    result = pipeline.import_theme(extract, dest)
    assert result["ok"], result
    assert result["slug"] == "my-pack"
    assert len(result["entry"]["schemes"]) == 2
    doc = json.loads(Path(result["path"], "theme.json").read_text(encoding="utf-8"))
    assert doc["name"] == "My Pack"
    assert set(doc["schemeData"]) >= {"NORMALBLUE", "NORMALHOMESTEAD"}


def test_probe_extract_lists_schemes(tmp_path: Path):
    extract = tmp_path / "src"
    _write_min_extract(extract)
    result = pipeline.probe(extract)
    assert result["ok"]
    assert result["generation"] == "xp"
    ids = {s["id"].upper() for s in result["schemes"]}
    assert "NORMALBLUE" in ids
    assert "NORMALHOMESTEAD" in ids


def test_import_rejects_vista_tree(tmp_path: Path):
    images = tmp_path / "images"
    images.mkdir()
    for i in range(6):
        (images / f"x{i}.png").write_bytes(_tiny_png())
    result = pipeline.import_theme(tmp_path, tmp_path / "out")
    assert not result["ok"]
    assert result["errors"]


def test_sanitize_slug():
    assert pipeline.sanitize_slug("My Theme!!") == "my-theme"
    assert pipeline.sanitize_slug("@@@") == "theme"


def test_schemes_accept_normaldefault(tmp_path: Path):
    from quickxp_theme import schemes

    settings = tmp_path / "settings"
    settings.mkdir()
    (settings / "NORMALDEFAULT.ini").write_text(
        "[SysMetrics]\nBtnface=1 2 3\n[button.pushbutton]\nImageFile=A\\b.bmp\n",
        encoding="utf-8",
    )
    (settings / "THEMES.ini").write_text("[themes]\n", encoding="utf-8")
    listed = schemes.list_schemes(tmp_path)
    assert len(listed) == 1
    assert listed[0]["id"].upper() == "NORMALDEFAULT"
    assert listed[0]["label"] == "Default"


def test_schemes_prefer_normalnormal_over_compact(tmp_path: Path):
    """Concave-style packs use NORMALNORMAL / NORMALCOMPACT, not NORMALBLUE."""
    from quickxp_theme import schemes

    settings = tmp_path / "settings"
    settings.mkdir()
    body = "[SysMetrics]\nBtnface=1 2 3\n[button.pushbutton]\nImageFile=A\\b.bmp\n"
    (settings / "NORMALCOMPACT.ini").write_text(body, encoding="utf-8")
    (settings / "NORMALNORMAL.ini").write_text(body, encoding="utf-8")
    listed = schemes.list_schemes(tmp_path)
    assert [e["id"].upper() for e in listed] == ["NORMALNORMAL", "NORMALCOMPACT"]
    assert listed[0]["label"] == "Normal"


def test_find_msstyles_in_folder(tmp_path: Path):
    style = tmp_path / "pack"
    style.mkdir()
    ms = style / "zune.msstyles"
    ms.write_bytes(b"MZ")
    assert pipeline.find_msstyles(style) == ms
    assert pipeline.find_msstyles(ms) == ms
