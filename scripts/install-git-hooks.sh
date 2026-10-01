#!/usr/bin/env bash
# Point this clone at the versioned hooks in .githooks/ (pre-push runs tests).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git config core.hooksPath .githooks
chmod +x .githooks/pre-push scripts/run-tests.sh scripts/run-qml-tests.sh
echo "git hooksPath -> .githooks (pre-push will run scripts/run-tests.sh)"
