#!/usr/bin/env bash
# Print the manual smoke checklist (does not automate the shell).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec cat "$ROOT/docs/SMOKE.md"
