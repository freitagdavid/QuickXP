"""Minimal PE resource DLLs for Aero import tests."""

from __future__ import annotations

import struct


def build_pe(entries: list[tuple[str | int, str | int, bytes]]) -> bytes:
    """Build a PE32 whose resource section contains entries of (type, name, data)."""
    rsrc = _resource_section(entries, section_va=0x1000)
    raw_ptr = 0x200
    raw = rsrc + b"\x00" * ((0x200 - (len(rsrc) % 0x200)) % 0x200)

    dos = bytearray(0x80)
    dos[0:2] = b"MZ"
    struct.pack_into("<I", dos, 0x3C, 0x80)

    opt = bytearray(224)
    struct.pack_into("<H", opt, 0, 0x10B)
    struct.pack_into("<II", opt, 96 + 8 * 2, 0x1000, len(rsrc))

    coff = struct.pack("<HHIIIHH", 0x14C, 1, 0, 0, 0, len(opt), 0x0102)
    section = struct.pack(
        "<8sIIIIIIHHI",
        b".rsrc\0\0\0",
        len(rsrc),
        0x1000,
        len(raw),
        raw_ptr,
        0,
        0,
        0,
        0,
        0x40000040,
    )
    headers = bytes(dos) + b"PE\0\0" + coff + bytes(opt) + section
    if len(headers) > raw_ptr:
        raise RuntimeError(f"PE headers are {len(headers)} bytes")
    return headers + b"\x00" * (raw_ptr - len(headers)) + raw


def _resource_section(entries: list[tuple], section_va: int) -> bytes:
    """Root directory sits at offset 0, which is what the PE loader expects."""
    grouped: dict[str | int, dict[str | int, bytes]] = {}
    for restype, name, data in entries:
        grouped.setdefault(restype, {})[name] = data

    dir_header = 16
    n_types = len(grouped)
    cursor = 0
    root_at = 0
    cursor += dir_header + n_types * 8
    type_at: dict[str | int, int] = {}
    name_at: dict[tuple, int] = {}
    for restype, names in _sorted_groups(grouped):
        type_at[restype] = cursor
        cursor += dir_header + len(names) * 8
        for name in _sorted_keys(names):
            name_at[(restype, name)] = cursor
            cursor += dir_header + 8
    data_at: dict[tuple, int] = {}
    for restype, names in _sorted_groups(grouped):
        for name in _sorted_keys(names):
            data_at[(restype, name)] = cursor
            cursor += 16

    strings = bytearray()
    string_at: dict[str, int] = {}

    def add_string(text: str) -> int:
        if text in string_at:
            return string_at[text]
        offset = cursor + len(strings)
        encoded = text.encode("utf-16le")
        strings.extend(struct.pack("<H", len(text)))
        strings.extend(encoded)
        if len(strings) % 2:
            strings.append(0)
        string_at[text] = offset
        return offset

    for restype, names in grouped.items():
        if isinstance(restype, str):
            add_string(restype)
        for name in names:
            if isinstance(name, str):
                add_string(name)

    payload_base = cursor + len(strings)
    if payload_base % 4:
        strings.extend(b"\x00" * (4 - (payload_base % 4)))
        payload_base = cursor + len(strings)

    payload = bytearray()
    payload_at: dict[tuple, int] = {}
    for restype, names in _sorted_groups(grouped):
        for name in _sorted_keys(names):
            if len(payload) % 4:
                payload.extend(b"\x00" * (4 - (len(payload) % 4)))
            payload_at[(restype, name)] = payload_base + len(payload)
            payload.extend(names[name])

    out = bytearray(cursor)
    out.extend(strings)
    out.extend(payload)

    def write_dir(offset: int, items: list[tuple[str | int, int, bool]]) -> None:
        named = [item for item in items if isinstance(item[0], str)]
        ids = [item for item in items if not isinstance(item[0], str)]
        struct.pack_into("<IIHHHH", out, offset, 0, 0, 0, 0, len(named), len(ids))
        entry = offset + 16
        for key, child, is_dir in named + ids:
            ident = (string_at[key] | 0x80000000) if isinstance(key, str) else int(key)
            field = child | (0x80000000 if is_dir else 0)
            struct.pack_into("<II", out, entry, ident, field)
            entry += 8

    write_dir(
        root_at,
        [(restype, type_at[restype], True) for restype, _names in _sorted_groups(grouped)],
    )
    for restype, names in _sorted_groups(grouped):
        write_dir(
            type_at[restype],
            [(name, name_at[(restype, name)], True) for name in _sorted_keys(names)],
        )
        for name in _sorted_keys(names):
            write_dir(name_at[(restype, name)], [(0x409, data_at[(restype, name)], False)])
            struct.pack_into(
                "<III",
                out,
                data_at[(restype, name)],
                section_va + payload_at[(restype, name)],
                len(names[name]),
                0,
            )
    return bytes(out)


def _sorted_keys(mapping: dict) -> list:
    named = sorted((key for key in mapping if isinstance(key, str)), key=str.lower)
    numbered = sorted(key for key in mapping if not isinstance(key, str))
    return named + numbered


def _sorted_groups(grouped: dict) -> list[tuple]:
    return [(key, grouped[key]) for key in _sorted_keys(grouped)]
