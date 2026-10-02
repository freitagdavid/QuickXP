# Python bridge tests

- [`test_tasks_bridge_preview_cache.py`](test_tasks_bridge_preview_cache.py) — TasksBridge preview path tokens
- [`test_tasks_bridge_windows.py`](test_tasks_bridge_windows.py) — SetWindows skip, apply-script inlining, stdin IPC parse/dispatch, WindowsRunner token, tasks-apply.js sync activate, prune-only helpers
- [`test_taskband_contracts.py`](test_taskband_contracts.py) — QML ownership: TasksBridge Process only in `TasksService`, no `Process` under `taskbar/`, stdinEnabled before running
- Shell ownership: `TasksService` singleton runs the single TasksBridge Process (multi-monitor TaskBars must not each spawn one)
- [`test_menu_bridge.py`](test_menu_bridge.py) — MenuBridge Programs trees (category + XDG XML fixtures)
- [`test_session_bridge.py`](test_session_bridge.py) — SessionBridge command resolution (no live power actions)
- [`test_recent_bridge.py`](test_recent_bridge.py) — RecentBridge xbel / GTK bookmarks parsing
