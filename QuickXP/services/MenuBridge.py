#!/usr/bin/env python3
"""Build Classic Start Programs trees from XDG menus (or category buckets).

CLI:
  MenuBridge.py xdg [--menu PATH]
  MenuBridge.py categories < apps.json

apps.json is a list of {id, name, icon, categories, noDisplay}.
stdout: JSON folder node {kind,id,label,icon,children}.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

CATEGORY_LABELS = {
    "AudioVideo": "Sound & Video",
    "Audio": "Sound & Video",
    "Video": "Sound & Video",
    "Development": "Development",
    "Education": "Education",
    "Game": "Games",
    "Graphics": "Graphics",
    "Network": "Internet",
    "Office": "Office",
    "Science": "Science",
    "Settings": "Settings",
    "System": "System Tools",
    "Utility": "Accessories",
    "Accessibility": "Accessibility",
}

CATEGORY_ORDER = [
    "Utility",
    "Development",
    "Education",
    "Game",
    "Graphics",
    "Network",
    "AudioVideo",
    "Office",
    "Science",
    "Settings",
    "System",
    "Accessibility",
]

SKIP_CATEGORIES = {
    "Core",
    "Qt",
    "GTK",
    "GNOME",
    "KDE",
    "XFCE",
    "X_Red_Hat_Base",
}

MENU_CANDIDATES = (
    "applications.menu",
    "plasma-applications.menu",
    "arch-applications.menu",
    "kf5-applications.menu",
    "gnome-applications.menu",
)


def folder_node(node_id: str, label: str, icon: str, children: list[dict]) -> dict:
    return {
        "kind": "folder",
        "id": node_id,
        "label": label,
        "icon": icon or "",
        "children": children,
    }


def app_node(entry_id: str, label: str, icon: str) -> dict:
    return {
        "kind": "app",
        "id": entry_id,
        "entryId": entry_id,
        "label": label,
        "icon": icon or "",
        "children": [],
    }


def desktop_id(raw: str) -> str:
    text = (raw or "").strip()
    if text.endswith(".desktop"):
        text = text[: -len(".desktop")]
    return text


def desktop_entry_id(desktop: Any) -> str:
    """Resolve a pyxdg DesktopEntry id without relying on getId() (not always present)."""
    for attr in ("getId", "getFileName"):
        fn = getattr(desktop, attr, None)
        if callable(fn):
            try:
                value = fn()
                if value:
                    return desktop_id(str(value))
            except Exception:
                pass
    filename = getattr(desktop, "filename", None) or getattr(desktop, "Filename", None) or ""
    return desktop_id(Path(str(filename)).name)


def primary_category(categories: list[str]) -> str:
    cats = [str(c) for c in categories or []]
    for key in CATEGORY_ORDER:
        if key in cats:
            return key
    for cat in cats:
        if cat and cat not in SKIP_CATEGORIES and not cat.startswith("X-"):
            return cat
    return ""


def build_category_tree(apps: list[dict]) -> dict:
    buckets: dict[str, list[dict]] = {}
    for entry in apps:
        if entry.get("noDisplay"):
            continue
        name = str(entry.get("name") or "").strip()
        eid = desktop_id(str(entry.get("id") or ""))
        if not name or not eid:
            continue
        key = primary_category(list(entry.get("categories") or [])) or "Other"
        buckets.setdefault(key, []).append(app_node(eid, name, str(entry.get("icon") or "")))

    children: list[dict] = []
    seen: set[str] = set()
    for key in CATEGORY_ORDER:
        items = buckets.get(key) or []
        if not items:
            continue
        seen.add(key)
        items.sort(key=lambda n: n["label"].lower())
        children.append(
            folder_node(f"cat:{key}", CATEGORY_LABELS.get(key, key), "", items)
        )
    for key in sorted(buckets):
        if key in seen or not buckets[key]:
            continue
        items = sorted(buckets[key], key=lambda n: n["label"].lower())
        label = "Other" if key == "Other" else CATEGORY_LABELS.get(key, key)
        children.append(folder_node(f"cat:{key}", label, "", items))
    return folder_node("programs", "Programs", "", children)


def local_name(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def collect_include_categories(include_el: ET.Element) -> list[str]:
    """Collect Category names under Include (flattened; And → all listed cats)."""
    cats: list[str] = []
    for el in include_el.iter():
        if local_name(el.tag) == "Category" and (el.text or "").strip():
            cats.append(el.text.strip())
    return cats


def collect_include_filenames(include_el: ET.Element) -> list[str]:
    names: list[str] = []
    for el in include_el.iter():
        if local_name(el.tag) == "Filename" and (el.text or "").strip():
            names.append(desktop_id(el.text.strip()))
    return names


def match_apps_for_menu(menu_el: ET.Element, apps_by_id: dict[str, dict], apps: list[dict]) -> list[dict]:
    include_cats: set[str] = set()
    include_files: set[str] = set()
    for child in list(menu_el):
        if local_name(child.tag) != "Include":
            continue
        include_cats.update(collect_include_categories(child))
        include_files.update(collect_include_filenames(child))

    matched: list[dict] = []
    seen: set[str] = set()
    for fid in sorted(include_files):
        entry = apps_by_id.get(fid)
        if not entry or entry.get("noDisplay"):
            continue
        name = str(entry.get("name") or "").strip()
        if not name or fid in seen:
            continue
        seen.add(fid)
        matched.append(app_node(fid, name, str(entry.get("icon") or "")))

    if include_cats:
        for entry in apps:
            eid = desktop_id(str(entry.get("id") or ""))
            if not eid or eid in seen or entry.get("noDisplay"):
                continue
            cats = set(str(c) for c in (entry.get("categories") or []))
            if not cats.intersection(include_cats):
                continue
            name = str(entry.get("name") or "").strip()
            if not name:
                continue
            seen.add(eid)
            matched.append(app_node(eid, name, str(entry.get("icon") or "")))

    matched.sort(key=lambda n: n["label"].lower())
    return matched


def parse_menu_element(menu_el: ET.Element, apps_by_id: dict[str, dict], apps: list[dict], path: str) -> dict | None:
    name = "Menu"
    for child in list(menu_el):
        if local_name(child.tag) == "Name" and (child.text or "").strip():
            name = child.text.strip()
            break

    children: list[dict] = []
    for child in list(menu_el):
        if local_name(child.tag) == "Menu":
            sub = parse_menu_element(child, apps_by_id, apps, f"{path}/{name}")
            if sub and sub.get("children"):
                children.append(sub)

    children.extend(match_apps_for_menu(menu_el, apps_by_id, apps))
    if not children:
        return None
    node_id = f"menu:{path}/{name}".replace("//", "/")
    return folder_node(node_id, name, "", children)


def build_xdg_tree_from_xml(menu_path: Path, apps: list[dict]) -> dict:
    tree = ET.parse(menu_path)
    root = tree.getroot()
    if local_name(root.tag) != "Menu":
        raise ValueError(f"not a menu root: {menu_path}")
    apps_by_id = {desktop_id(str(a.get("id") or "")): a for a in apps}
    parsed = parse_menu_element(root, apps_by_id, apps, "")
    if parsed is None:
        return folder_node("programs", "Programs", "", [])
    # Root XDG menu is often "Applications"; Classic Start wraps as Programs.
    return folder_node("programs", "Programs", "", parsed.get("children") or [])


def build_xdg_tree_pyxdg(menu_path: Path | None) -> dict | None:
    try:
        import xdg.Menu as XdgMenu  # type: ignore
    except ImportError:
        return None

    path = str(menu_path) if menu_path else None
    try:
        menu = XdgMenu.parse(path) if path else XdgMenu.parse()
    except Exception as error:
        print(f"quickxp menu: pyxdg parse failed: {error}", file=sys.stderr)
        return None

    def walk(node) -> dict | None:
        children: list[dict] = []
        for entry in node.getEntries():
            if isinstance(entry, XdgMenu.Menu):
                if getattr(entry, "Show", True) is False:
                    continue
                sub = walk(entry)
                if sub and sub.get("children"):
                    children.append(sub)
            elif isinstance(entry, XdgMenu.MenuEntry):
                desktop = entry.DesktopEntry
                if desktop.getNoDisplay():
                    continue
                label = desktop.getName() or ""
                if not label.strip():
                    continue
                eid = desktop_entry_id(desktop)
                if not eid:
                    continue
                children.append(app_node(eid, label, desktop.getIcon() or ""))
        if not children:
            return None
        label = node.getName() or node.Name or "Menu"
        icon = ""
        try:
            icon = node.getIcon() or ""
        except Exception:
            icon = ""
        path_name = ""
        try:
            path_name = node.getPath() or node.Name or label
        except Exception:
            path_name = label
        return folder_node(f"menu:{path_name}", label, icon, children)

    try:
        walked = walk(menu)
    except Exception as error:
        print(f"quickxp menu: pyxdg walk failed: {error}", file=sys.stderr)
        return None
    if walked is None:
        return folder_node("programs", "Programs", "", [])
    return folder_node("programs", "Programs", "", walked.get("children") or [])


def find_menu_file(explicit: str | None) -> Path | None:
    if explicit:
        path = Path(explicit).expanduser()
        return path if path.is_file() else None
    xdg_config = os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg")
    roots = [Path(p) for p in xdg_config.split(":") if p]
    roots.append(Path.home() / ".config")
    for root in roots:
        menus = root / "menus"
        for name in MENU_CANDIDATES:
            candidate = menus / name
            if candidate.is_file():
                return candidate
        # Also accept any *-applications.menu
        if menus.is_dir():
            for candidate in sorted(menus.glob("*-applications.menu")):
                if candidate.is_file():
                    return candidate
    return None


def load_apps_json(raw: str) -> list[dict]:
    data = json.loads(raw or "[]")
    if not isinstance(data, list):
        raise ValueError("apps json must be a list")
    return data


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="QuickXP Start Programs menu bridge")
    parser.add_argument("mode", choices=("xdg", "categories"))
    parser.add_argument("--menu", default="", help="Path to applications.menu")
    parser.add_argument(
        "--apps-json",
        default="",
        help="Path to apps JSON (default: stdin for categories / xml xdg fallback)",
    )
    args = parser.parse_args(argv)

    apps: list[dict] = []
    if args.apps_json:
        apps = load_apps_json(Path(args.apps_json).read_text(encoding="utf-8"))
    elif args.mode == "categories" or (args.mode == "xdg" and args.menu):
        apps = load_apps_json(sys.stdin.read())

    if args.mode == "categories":
        tree = build_category_tree(apps)
        json.dump(tree, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 0

    menu_path = find_menu_file(args.menu or None)
    tree: dict[str, Any] | None = None
    if not args.apps_json and not args.menu:
        try:
            tree = build_xdg_tree_pyxdg(menu_path)
        except Exception as error:
            print(f"quickxp menu: pyxdg failed: {error}", file=sys.stderr)
            tree = None
    if tree is None:
        if menu_path is None:
            print("quickxp menu: no applications.menu found", file=sys.stderr)
            tree = folder_node("programs", "Programs", "", [])
        else:
            if not apps:
                apps = load_apps_json(sys.stdin.read()) if not sys.stdin.isatty() else []
            tree = build_xdg_tree_from_xml(menu_path, apps)
    json.dump(tree, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
