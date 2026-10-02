#!/usr/bin/env bash
# Run the QuickXP test suite (pytest + qmltestrunner). Used by pre-push and CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

pick_python() {
  local candidate
  for candidate in \
    "${QUICKXP_PYTHON:-}" \
    python3 \
    python \
    /usr/bin/python3 \
    /usr/bin/python3.14 \
    /usr/bin/python3.12 \
    "$HOME/.local/share/mise/installs/python/3.14.4/bin/python3" \
    "$HOME/.local/share/mise/installs/python/3.12.13/bin/python3"
  do
    [[ -n "$candidate" ]] || continue
    if [[ -x "$candidate" ]] || command -v "$candidate" >/dev/null 2>&1; then
      if "$candidate" -c 'import pytest' 2>/dev/null; then
        if command -v "$candidate" >/dev/null 2>&1 && [[ ! -x "$candidate" || "$candidate" != /* ]]; then
          command -v "$candidate"
        else
          printf '%s\n' "$candidate"
        fi
        return 0
      fi
    fi
  done
  return 1
}

PYTHON="$(pick_python || true)"
if [[ -z "$PYTHON" ]]; then
  echo "No Python with pytest found. Install with one of:" >&2
  echo "  python3 -m pip install 'pytest>=8'" >&2
  echo "  /usr/bin/python3 -m pip install --user 'pytest>=8'" >&2
  echo "Or set QUICKXP_PYTHON to an interpreter that has pytest." >&2
  exit 1
fi

echo "==> pytest"
"$PYTHON" -m pytest tests/

if [[ "${QUICKXP_SKIP_QML:-}" == "1" ]]; then
  echo "==> qmltestrunner skipped (QUICKXP_SKIP_QML=1)"
  exit 0
fi

QMLTEST="${QUICKXP_QMLTESTRUNNER:-}"
if [[ -z "$QMLTEST" ]]; then
  for candidate in \
    /usr/lib/qt6/bin/qmltestrunner \
    qmltestrunner-qt6 \
    qmltestrunner \
    /usr/bin/qmltestrunner \
    /usr/sbin/qmltestrunner
  do
    if [[ -x "$candidate" ]]; then
      QMLTEST="$candidate"
      break
    elif command -v "$candidate" >/dev/null 2>&1; then
      QMLTEST="$(command -v "$candidate")"
      break
    fi
  done
fi

if [[ -z "$QMLTEST" ]]; then
  echo "qmltestrunner not found — install Qt Quick Test or set QUICKXP_SKIP_QML=1" >&2
  exit 1
fi

echo "==> qmltestrunner ($QMLTEST)"
# Headless-friendly default; callers can override (e.g. QT_QPA_PLATFORM=xcb).
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
"$QMLTEST" -input "$ROOT/tests/qml"
