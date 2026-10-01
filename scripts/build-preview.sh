#!/bin/sh
# Build QuickXP/services/preview/quickxp-preview (KWin ScreenShot2 helper).
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
dir="$root/QuickXP/services/preview"
out="$dir/quickxp-preview"
cpp="$dir/quickxp-preview.cpp"

CXX="${CXX:-}"
if [ -z "$CXX" ]; then
  for candidate in g++ c++ clang++; do
    if command -v "$candidate" >/dev/null 2>&1; then
      CXX="$candidate"
      break
    fi
  done
fi

if [ -z "$CXX" ]; then
  echo "No C++ compiler found (g++ / clang++). Install a toolchain." >&2
  exit 1
fi

if ! pkg-config --exists Qt6DBus Qt6Gui; then
  echo "Qt6DBus / Qt6Gui not found via pkg-config." >&2
  echo "Install Qt6 development packages (names vary by distro)." >&2
  exit 1
fi

# -fPIC avoids copy-relocation link errors against modern Qt6 shared libs.
# shellcheck disable=SC2046
"$CXX" -O2 -fPIC -o "$out" "$cpp" $(pkg-config --cflags --libs Qt6DBus Qt6Gui)
chmod +x "$out"
echo "built $out"
