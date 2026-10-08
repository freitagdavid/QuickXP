#!/usr/bin/env python3
"""Locate and rewrite XDG desktop entries for Start shortcut properties.

CLI:
  DesktopFile.py locate DESKTOP_ID
  DesktopFile.py save DESKTOP_ID PAYLOAD_JSON

locate prints one JSON object. save writes a user override under
$XDG_DATA_HOME/applications and never modifies a system file.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

FIELD_CODE_CHARS = set("fFuUdDnNickvm")


def desktop_filename(raw: str) -> str:
    """Normalize a Start entry id to a single applications/ basename."""
    text = (raw or "").strip()
    if not text or "/" in text or "\\" in text or text.startswith("."):
        raise ValueError("bad desktop id")
    if not text.endswith(".desktop"):
        text += ".desktop"
    if text == ".desktop" or text.startswith("."):
        raise ValueError("bad desktop id")
    return text


def data_home_dir(env: dict | None = None) -> str:
    src = os.environ if env is None else env
    home = src.get("XDG_DATA_HOME", "").strip()
    if home:
        return home
    return str(Path(src.get("HOME", str(Path.home()))) / ".local" / "share")


def data_dir_list(env: dict | None = None) -> list[str]:
    src = os.environ if env is None else env
    raw = src.get("XDG_DATA_DIRS", "").strip()
    if not raw:
        raw = "/usr/local/share:/usr/share"
    return [part for part in raw.split(":") if part]


def application_roots(data_home: str, data_dirs: list[str]) -> list[Path]:
    roots: list[Path] = []
    seen: set[str] = set()
    for base in [data_home, *data_dirs]:
        if not base:
            continue
        apps = str(Path(base) / "applications")
        if apps in seen:
            continue
        seen.add(apps)
        roots.append(Path(apps))
    return roots


def find_desktop_file(filename: str, data_home: str, data_dirs: list[str]) -> Path | None:
    """User applications/ wins, then system dirs. Direct file, then vendor subdirs."""
    for apps in application_roots(data_home, data_dirs):
        direct = apps / filename
        if direct.is_file():
            return direct
        if not apps.is_dir():
            continue
        nested: list[Path] = []
        try:
            children = list(apps.iterdir())
        except OSError:
            continue
        for child in children:
            if child.is_dir():
                cand = child / filename
                if cand.is_file():
                    nested.append(cand)
        if nested:
            nested.sort()
            return nested[0]
        try:
            for cand in sorted(apps.rglob(filename)):
                if cand.is_file():
                    return cand
        except OSError:
            continue
    return None


def tokenize_exec(exec_str: str) -> list[str]:
    """Split an Exec value, honoring quotes and backslash escapes."""
    text = exec_str or ""
    tokens: list[str] = []
    buf: list[str] = []
    quote: str | None = None
    i = 0
    while i < len(text):
        char = text[i]
        if quote:
            if char == quote:
                quote = None
            elif char == "\\" and i + 1 < len(text):
                buf.append(text[i + 1])
                i += 1
            else:
                buf.append(char)
        elif char in " \t":
            if buf:
                tokens.append("".join(buf))
                buf = []
        elif char in "\"'":
            quote = char
        elif char == "\\" and i + 1 < len(text):
            buf.append(text[i + 1])
            i += 1
        else:
            buf.append(char)
        i += 1
    if buf:
        tokens.append("".join(buf))
    return tokens


def is_field_code(token: str) -> bool:
    return len(token) == 2 and token[0] == "%" and (token[1] in FIELD_CODE_CHARS or token[1] == "%")


def exec_binary_token(exec_str: str) -> str:
    """First Exec argument that is not a desktop field code."""
    for token in tokenize_exec(exec_str):
        if is_field_code(token):
            continue
        return token.replace("%%", "%")
    return ""


def resolve_binary(token: str, *, path_env: str, cwd: str = "", exists=None) -> str:
    """Absolute path of the executable, or empty when it is not on disk."""
    if exists is None:
        exists = os.path.isfile
    text = (token or "").strip()
    if not text:
        return ""
    if text.startswith("/"):
        return text if exists(text) else ""
    if "/" in text:
        candidate = str(Path(cwd or ".") / text)
        return candidate if exists(candidate) else ""
    for directory in (path_env or "").split(":"):
        if not directory:
            continue
        candidate = str(Path(directory) / text)
        if exists(candidate):
            return candidate
    return ""


def unescape_value(value: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(value):
        char = value[i]
        if char == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"s": " ", "n": "\n", "t": "\t", "r": "\r", "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        out.append(char)
        i += 1
    return "".join(out)


def escape_value(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("\r", "\\r")
    )


def _group_span(lines: list[str]) -> tuple[int, int]:
    """Return [start, end) line indexes of the first [Desktop Entry] group."""
    start = -1
    for i, raw in enumerate(lines):
        if raw.strip().lower() == "[desktop entry]":
            start = i
            break
    if start < 0:
        return -1, -1
    end = len(lines)
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            end = i
            break
    return start, end


def read_desktop_fields(text: str) -> dict:
    start, end = _group_span(text.splitlines())
    fields = {
        "name": "",
        "comment": "",
        "icon": "",
        "exec": "",
        "workingDirectory": "",
        "terminal": False,
    }
    if start < 0:
        return fields
    lines = text.splitlines()
    for raw in lines[start + 1 : end]:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key, val = stripped.split("=", 1)
        key = key.strip()
        if "[" in key:
            continue
        val = unescape_value(val.strip())
        lowered = key.lower()
        if lowered == "name":
            fields["name"] = val
        elif lowered == "comment":
            fields["comment"] = val
        elif lowered == "icon":
            fields["icon"] = val
        elif lowered == "exec":
            fields["exec"] = val
        elif lowered == "path":
            fields["workingDirectory"] = val
        elif lowered == "terminal":
            fields["terminal"] = val.lower() == "true"
    return fields


def apply_fields(text: str, updates: dict[str, str]) -> str:
    """Set unlocalized keys inside [Desktop Entry], preserving every other line."""
    body = text if text is not None else ""
    if "[desktop entry]" not in body.lower():
        prefix = "[Desktop Entry]\nType=Application\n"
        body = prefix + (body if not body or body.startswith("\n") else "")
        if body and not body.endswith("\n"):
            body += "\n"
    newline = "\r\n" if "\r\n" in body else "\n"
    lines = body.splitlines()
    start, end = _group_span(lines)
    if start < 0:
        lines = ["[Desktop Entry]", "Type=Application", *lines]
        start, end = _group_span(lines)
    pending = {key: value for key, value in updates.items()}
    for i in range(start + 1, end):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue
        key = stripped.split("=", 1)[0].strip()
        if "[" in key or key not in pending:
            continue
        lines[i] = f"{key}={escape_value(pending.pop(key))}"
    if pending:
        insert_at = end
        extra = [f"{key}={escape_value(pending[key])}" for key in pending]
        lines[insert_at:insert_at] = extra
    rendered = newline.join(lines)
    if body.endswith(("\n", "\r\n")) or not rendered.endswith("\n"):
        rendered += newline
    return rendered


def locate_entry(
    desktop_id: str,
    *,
    env: dict | None = None,
    exists=None,
) -> dict:
    src = os.environ if env is None else env
    try:
        filename = desktop_filename(desktop_id)
    except ValueError as error:
        return {"ok": False, "error": str(error)}
    home = data_home_dir(src)
    dirs = data_dir_list(src)
    path = find_desktop_file(filename, home, dirs)
    if path is None:
        return {"ok": False, "error": "not found", "id": filename}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as error:
        return {"ok": False, "error": str(error), "id": filename}
    fields = read_desktop_fields(text)
    token = exec_binary_token(fields["exec"])
    binary = resolve_binary(
        token,
        path_env=src.get("PATH", ""),
        cwd=fields["workingDirectory"],
        exists=exists,
    )
    return {
        "ok": True,
        "id": filename,
        "desktopPath": str(path),
        "name": fields["name"],
        "comment": fields["comment"],
        "icon": fields["icon"],
        "exec": fields["exec"],
        "workingDirectory": fields["workingDirectory"],
        "terminal": fields["terminal"],
        "binary": binary,
        "binaryExists": bool(binary),
    }


def user_desktop_path(desktop_id: str, data_home: str) -> Path:
    return Path(data_home) / "applications" / desktop_filename(desktop_id)


def save_entry(
    desktop_id: str,
    payload: dict,
    *,
    env: dict | None = None,
) -> dict:
    src = os.environ if env is None else env
    try:
        filename = desktop_filename(desktop_id)
    except ValueError as error:
        return {"ok": False, "error": str(error)}
    home = data_home_dir(src)
    dest = Path(home) / "applications" / filename
    if dest.is_file():
        try:
            text = dest.read_text(encoding="utf-8")
        except OSError as error:
            return {"ok": False, "error": str(error)}
    else:
        src_path = find_desktop_file(filename, home, data_dir_list(src))
        if src_path is None:
            text = "[Desktop Entry]\nType=Application\n"
        else:
            try:
                text = src_path.read_text(encoding="utf-8")
            except OSError as error:
                return {"ok": False, "error": str(error)}
    data = payload if isinstance(payload, dict) else {}
    terminal = data.get("terminal")
    terminal_text = "true" if terminal is True or str(terminal).lower() == "true" else "false"
    updated = apply_fields(
        text,
        {
            "Name": str(data.get("name") or ""),
            "Comment": str(data.get("comment") or ""),
            "Exec": str(data.get("exec") or ""),
            "Icon": str(data.get("icon") or ""),
            "Path": str(data.get("workingDirectory") or ""),
            "Terminal": terminal_text,
        },
    )
    try:
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + ".tmp")
        tmp.write_text(updated, encoding="utf-8")
        tmp.replace(dest)
    except OSError as error:
        return {"ok": False, "error": str(error)}
    return {"ok": True, "path": str(dest), "id": filename}


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args[0] in ("-h", "--help"):
        print(
            "usage: DesktopFile.py locate DESKTOP_ID\n"
            "       DesktopFile.py save DESKTOP_ID PAYLOAD_JSON",
            file=sys.stderr,
        )
        return 2
    cmd = args[0]
    if cmd == "locate":
        if len(args) not in (2, 3):
            print("usage: DesktopFile.py locate DESKTOP_ID [TOKEN]", file=sys.stderr)
            return 2
        result = locate_entry(args[1])
        if len(args) == 3:
            result["token"] = args[2]
        print(json.dumps(result))
        return 0 if result.get("ok") else 1
    if cmd == "save":
        if len(args) != 3:
            print("usage: DesktopFile.py save DESKTOP_ID PAYLOAD_JSON", file=sys.stderr)
            return 2
        try:
            payload = json.loads(args[2])
        except json.JSONDecodeError as error:
            print(json.dumps({"ok": False, "error": str(error)}))
            return 1
        if not isinstance(payload, dict):
            print(json.dumps({"ok": False, "error": "payload must be an object"}))
            return 1
        result = save_entry(args[1], payload)
        print(json.dumps(result))
        return 0 if result.get("ok") else 1
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
