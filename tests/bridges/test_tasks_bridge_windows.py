"""TasksBridge SetWindows skip + apply-script helpers (no live DBus/KWin)."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "QuickXP" / "services"))
import TasksBridge as tb  # noqa: E402


def test_normalize_windows_payload():
    assert tb.normalize_windows_payload("") == "[]"
    assert tb.normalize_windows_payload(None) == "[]"
    assert tb.normalize_windows_payload("[{}]") == "[{}]"


def test_apply_script_for():
    publish = ROOT / "QuickXP" / "services" / "kwin" / "tasks.js"
    apply = tb.apply_script_for(publish)
    assert apply.name == "tasks-apply.js"
    assert apply.is_file()


def test_atomic_write_and_skip_logic(tmp_path):
    state = tmp_path / "quickxp-tasks.json"
    text_a = '[{"id":"1","title":"A"}]'
    text_b = '[{"id":"1","title":"B"}]'

    last = None
    wrote = []

    def write_if_changed(payload, last_text):
        text = tb.normalize_windows_payload(payload)
        if text == last_text:
            return last_text, False
        tb.atomic_write(state, text)
        wrote.append(text)
        return text, True

    last, changed = write_if_changed(text_a, last)
    assert changed is True
    assert state.read_text() == text_a
    assert len(wrote) == 1

    last, changed = write_if_changed(text_a, last)
    assert changed is False
    assert len(wrote) == 1

    last, changed = write_if_changed(text_b, last)
    assert changed is True
    assert state.read_text() == text_b
    assert len(wrote) == 2


def test_build_apply_script_text_inlines_commands():
    helper = (ROOT / "QuickXP" / "services" / "kwin" / "tasks-apply.js").read_text()
    text = tb.build_apply_script_text(helper, [{"id": "abc", "action": "minimize"}])
    assert "function applyCommand" in text
    assert "abc" in text
    assert "minimize" in text
    assert "commands.forEach(applyCommand)" in text


def test_cmdline_is_tasks_bridge():
    assert tb._cmdline_is_tasks_bridge(
        ["/usr/bin/python3", "/home/x/.config/quickshell/default/QuickXP/services/TasksBridge.py"]
    )
    assert not tb._cmdline_is_tasks_bridge(["zsh", "-c", "pkill TasksBridge.py; true"])
    assert not tb._cmdline_is_tasks_bridge(["/usr/bin/python3", "/tmp/other.py"])


def test_stale_bridge_pids(tmp_path):
    def write_proc(pid: int, parts: list[str]) -> None:
        d = tmp_path / str(pid)
        d.mkdir()
        (d / "cmdline").write_bytes(b"\0".join(p.encode() for p in parts) + b"\0")

    write_proc(10, ["/usr/bin/python3", "/tmp/TasksBridge.py"])
    write_proc(11, ["/usr/bin/python3", "/tmp/other.py"])
    write_proc(12, ["zsh", "-c", "echo TasksBridge.py"])
    assert tb.stale_bridge_pids(tmp_path, self_pid=99) == [10]
    assert tb.stale_bridge_pids(tmp_path, self_pid=10) == []


def test_parse_stdin_line():
    assert tb.parse_stdin_line("") is None
    assert tb.parse_stdin_line("# comment") is None
    assert tb.parse_stdin_line("COMMAND {abc} activate") == {
        "op": "command",
        "window_id": "{abc}",
        "action": "activate",
    }
    assert tb.parse_stdin_line("PREVIEW 12 {abc}") == {
        "op": "preview",
        "serial": "12",
        "window_id": "{abc}",
    }
    assert tb.parse_stdin_line("SHOWDESKTOP") == {"op": "showdesktop"}
    assert tb.parse_stdin_line("NOPE") is None
    assert tb.parse_stdin_line("  COMMAND  {abc}  activate  ") == {
        "op": "command",
        "window_id": "{abc}",
        "action": "activate",
    }


def test_plan_show_desktop_minimize_and_restore():
    rows = [
        {"id": "a", "minimized": False, "minimizable": True},
        {"id": "b", "minimized": True, "minimizable": True},
    ]
    cmds, snap = tb.plan_show_desktop(rows, None)
    assert snap is not None
    assert len(snap) == 2
    assert {"id": "a", "action": "minimize"} in cmds
    assert all(c["id"] != "b" for c in cmds)
    restore, cleared = tb.plan_show_desktop(rows, snap)
    assert cleared is None
    assert {"id": "a", "action": "unminimize"} in restore
    assert all(c["id"] != "b" for c in restore)


def test_dispatch_showdesktop():
    hits = []
    assert (
        tb.dispatch_stdin_message(
            tb.parse_stdin_line("SHOWDESKTOP"),
            on_showdesktop=lambda: hits.append(True),
        )
        == "showdesktop"
    )
    assert hits == [True]


def test_windows_runner_token():
    assert tb.windows_runner_token("") == ""
    assert tb.windows_runner_token("{abc}") == "0_{abc}"
    assert tb.windows_runner_token("0_{abc}") == "0_{abc}"
    assert tb.windows_runner_token("  {x}  ") == "0_{x}"


def test_dispatch_stdin_message_command_activate():
    calls = []
    msg = tb.parse_stdin_line("COMMAND {abc} activate")
    handled = tb.dispatch_stdin_message(
        msg,
        on_command=lambda wid, action: calls.append((wid, action)),
        on_preview=lambda *_: calls.append("preview"),
    )
    assert handled == "command"
    assert calls == [("{abc}", "activate")]


def test_dispatch_stdin_message_preview_and_ignore():
    commands = []
    previews = []
    assert (
        tb.dispatch_stdin_message(
            tb.parse_stdin_line("PREVIEW 9 {w}"),
            on_command=lambda *a: commands.append(a),
            on_preview=lambda *a: previews.append(a),
        )
        == "preview"
    )
    assert commands == []
    assert previews == [("9", "{w}")]
    assert tb.dispatch_stdin_message(None, on_command=lambda *_: None) is None
    assert tb.dispatch_stdin_message({"op": "nope"}, on_command=lambda *_: None) is None


def test_format_preview_reply():
    assert tb.format_preview_reply("3", "/tmp/x.png") == "PREVIEW 3 /tmp/x.png"
    assert tb.format_preview_reply("3", None) == "PREVIEW 3 -"


def test_tasks_apply_js_sync_activate_contract():
    helper = (ROOT / "QuickXP" / "services" / "kwin" / "tasks-apply.js").read_text()
    assert "workspace.activeWindow = window" in helper
    assert "function applyCommand" in helper
    assert 'action === "minimize"' in helper
    assert 'action === "unminimize"' in helper
    assert 'action === "close"' in helper
    # Default branch calls activate(window) for activate and unknown actions.
    assert "activate(window)" in helper
    text = tb.build_apply_script_text(helper, [{"id": "x", "action": "activate"}])
    assert "commands.forEach(applyCommand)" in text
    assert '"action": "activate"' in text


def test_prune_stale_preview_files(tmp_path):
    live = {"{aaaa-bbbb}"}
    keep = tmp_path / f"quickxp-preview-w-{tb.safe_window_token('{aaaa-bbbb}')}.png"
    drop = tmp_path / "quickxp-preview-w-_dead-id_.png"
    keep.write_bytes(b"ok")
    drop.write_bytes(b"gone")
    removed = tb.prune_stale_preview_files(tmp_path, live)
    assert keep.is_file()
    assert not drop.is_file()
    assert drop in removed


def test_live_window_ids():
    assert tb.live_window_ids([{"id": "1"}, {"id": ""}, "x", {"id": "2"}]) == {"1", "2"}
