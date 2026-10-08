#!/bin/sh
# Link the QuickXP Wayland session into SDDM's session directory.
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
script="$root/session/quickxp-session"
chmod +x "$script"

bindir="${HOME}/.local/bin"
mkdir -p "$bindir"
ln -sfn "$script" "$bindir/quickxp-session"

data="${XDG_DATA_HOME:-${HOME}/.local/share}/quickxp"
mkdir -p "$data"
desktop="$data/quickxp.desktop"
cat > "$desktop" <<EOF
[Desktop Entry]
Name=QuickXP
Comment=KWin with Quickshell, without Plasma
Exec=${bindir}/quickxp-session
TryExec=${bindir}/quickxp-session
Type=Application
DesktopNames=QuickXP
EOF

system_dir=/usr/share/wayland-sessions
target="$system_dir/quickxp.desktop"

link_system() {
  ln -sfn "$desktop" "$target"
}

if [ -w "$system_dir" ]; then
  link_system
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo ln -sfn "$desktop" "$target"
else
  echo "quickxp session script: $bindir/quickxp-session" >&2
  echo "SDDM only reads $system_dir. Link the desktop entry with:" >&2
  echo "  sudo ln -sfn \"$desktop\" \"$target\"" >&2
  exit 1
fi

echo "QuickXP session installed. Log out and choose QuickXP in the display manager."
