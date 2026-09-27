#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
config="${HOME}/.config/quickshell/default"

mkdir -p "$config"
ln -sfn "$root/src" "$config/QuickXP"
cp -f "$root/shell.qml" "$config/shell.qml"
