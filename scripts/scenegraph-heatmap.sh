#!/usr/bin/env bash
# Launch Quickshell with a Qt Quick scene-graph overlay.
# Default is the overdraw heatmap: redder pixels were painted more than once.
#
# Usage:
#   ./scripts/scenegraph-heatmap.sh
#   ./scripts/scenegraph-heatmap.sh changes
#   ./scripts/scenegraph-heatmap.sh batches
#   ./scripts/scenegraph-heatmap.sh clipping
#
# Quit this Quickshell process to return to a normal shell. A Quickshell
# instance that is already running will not pick up the overlay.
set -euo pipefail

mode="${1:-overdraw}"
case "$mode" in
  overdraw | changes | batches | clipping) ;;
  -h | --help)
    echo "usage: $0 [overdraw|changes|batches|clipping] [quickshell args...]" >&2
    exit 0
    ;;
  *)
    echo "usage: $0 [overdraw|changes|batches|clipping] [quickshell args...]" >&2
    exit 2
    ;;
esac
shift || true

if command -v quickshell >/dev/null 2>&1; then
  bin="$(command -v quickshell)"
elif command -v qs >/dev/null 2>&1; then
  bin="$(command -v qs)"
else
  echo "quickshell not found" >&2
  exit 1
fi

export QSG_VISUALIZE="$mode"
echo "QSG_VISUALIZE=$mode — quit this Quickshell to restore the normal shell." >&2
exec "$bin" "$@"
