#!/usr/bin/env bash
# Thin wrapper around qmltestrunner for the tests/qml suite.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export QUICKXP_SKIP_QML=0
# Re-use discovery from run-tests.sh but only the QML half.
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
  echo "qmltestrunner not found" >&2
  exit 1
fi

exec "$QMLTEST" -input "$ROOT/tests/qml"
