#!/bin/sh
# One-shot setup after cloning QuickXP: check deps, build peek helper, deploy.
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"

ok=1

have() {
  command -v "$1" >/dev/null 2>&1
}

echo "==> Checking dependencies"

if have quickshell || have qs; then
  echo "  quickshell: ok"
else
  echo "  quickshell: MISSING — install from https://quickshell.org/" >&2
  ok=0
fi

if have python3; then
  echo "  python3: ok"
else
  echo "  python3: MISSING" >&2
  ok=0
fi

# KDE task bridge needs these; non-KDE users can skip peeks/bridge.
if have python3; then
  if python3 -c "import dbus, gi" 2>/dev/null; then
    echo "  python dbus + gi: ok"
  else
    echo "  python dbus + gi: MISSING (needed on KDE for the window list / peeks)" >&2
    echo "    Arch: pacman -S python-dbus python-gobject" >&2
    echo "    Fedora: dnf install python3-dbus python3-gobject" >&2
    echo "    Debian/Ubuntu: apt install python3-dbus python3-gi" >&2
    ok=0
  fi
fi

if [ "${XDG_CURRENT_DESKTOP:-}" != "${XDG_CURRENT_DESKTOP#*KDE}" ] || [ "${KDE_FULL_SESSION:-}" = "true" ]; then
  echo "  session: KDE detected (KWin bridge will be used)"
  if ! have qdbus6 && ! have qdbus; then
    echo "  qdbus6: MISSING (used to talk to the task bridge)" >&2
    ok=0
  else
    echo "  qdbus: ok"
  fi
else
  echo "  session: not KDE (foreign-toplevel task list; peeks limited)"
fi

if [ "$ok" -ne 1 ]; then
  echo "" >&2
  echo "Fix the missing dependencies above, then re-run: ./scripts/setup.sh" >&2
  exit 1
fi

echo "==> Building quickxp-preview"
if ! "$root/scripts/build-preview.sh"; then
  if [ -x "$root/src/quickxp-preview" ]; then
    echo "  build failed; keeping existing src/quickxp-preview" >&2
  else
    echo "  build failed and no preview binary is present (KDE peeks will not work)" >&2
    echo "  install Qt6DBus/Qt6Gui dev packages and a C++ compiler, then:" >&2
    echo "    ./scripts/build-preview.sh" >&2
  fi
fi

echo "==> Deploying into ~/.config/quickshell/default"
"$root/deploy.sh"

echo ""
echo "Setup complete. Start or reload Quickshell:"
echo "  quickshell"
echo ""
echo "On Plasma, hide or disable the stock panel so it does not sit on top of QuickXP."
echo "Roadmap: docs/ROADMAP.md"
