#!/usr/bin/bash
# Preview the QuickXP QML window decoration in a windowed nested KWin.
# Restarts that compositor when decoration sources change.
# Does not write the session kwinrc or ~/.local/share/kwin/decorations.
#
#   ./scripts/preview-kdecoration.sh
#   ./scripts/preview-kdecoration.sh QuickXP/themes/aero
set -euo pipefail

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
theme_arg="${1:-$root/QuickXP/themes/aero}"
if [[ "$theme_arg" != /* ]]; then
    theme_arg="$root/$theme_arg"
fi
theme_root="$(CDPATH= cd -- "$theme_arg" && pwd)"
template_ui="$root/QuickXP/kwin-decoration/contents/ui"
theme_pkg="$theme_root/kdecoration"
client_qml="$root/scripts/decoration-preview.qml"

for cmd in kwin_wayland qml6 inotifywait python3 setsid; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "preview-kdecoration: missing $cmd" >&2
        exit 1
    fi
done
qml6_bin="$(command -v qml6)"

if [[ ! -f "$theme_pkg/metadata.json" ]]; then
    echo "preview-kdecoration: no kdecoration package at $theme_pkg" >&2
    exit 1
fi
if [[ ! -f "$template_ui/main.qml" ]]; then
    echo "preview-kdecoration: decoration template missing at $template_ui" >&2
    exit 1
fi

plugin_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Id"])' "$theme_pkg/metadata.json")"
if [[ -z "$plugin_id" ]]; then
    echo "preview-kdecoration: metadata.json has no KPlugin.Id" >&2
    exit 1
fi

runtime="${XDG_RUNTIME_DIR:-/tmp}"
if [[ ! -d "$runtime" || ! -w "$runtime" ]]; then
    runtime=/tmp
fi
preview_root="$(mktemp -d "$runtime/quickxp-deco-preview.XXXXXX")"
export XDG_CONFIG_HOME="$preview_root/config"
export XDG_DATA_HOME="$preview_root/data"
# KWin starts each positional argument as its own program, so the client has
# to be a single executable. Cursor's terminal also exports a Qt 5 plugin path
# that would break this Qt 6 process.
client_launch="$preview_root/run-client.sh"
cat >"$client_launch" <<EOF
#!/usr/bin/bash
unset QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH QML2_IMPORT_PATH
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
exec $(printf '%q' "$qml6_bin") $(printf '%q' "$client_qml")
EOF
chmod +x "$client_launch"
kwin_pid=""
watch_pid=""

cleanup() {
    if [[ -n "$watch_pid" ]]; then
        kill "$watch_pid" 2>/dev/null || true
        wait "$watch_pid" 2>/dev/null || true
        watch_pid=""
    fi
    if [[ -n "$kwin_pid" ]]; then
        kill -- "-$kwin_pid" 2>/dev/null || kill "$kwin_pid" 2>/dev/null || true
        wait "$kwin_pid" 2>/dev/null || true
        kwin_pid=""
    fi
    if [[ -n "$preview_root" && -d "$preview_root" ]]; then
        rm -rf "$preview_root"
    fi
}

on_signal() {
    cleanup
    exit 130
}
trap on_signal INT TERM

stage_package() {
    local dest="$XDG_DATA_HOME/kwin/decorations/$plugin_id"
    local name
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$theme_pkg/." "$dest/"
    for name in main.qml CaptionButton.qml FrameImage.qml; do
        cp -a "$template_ui/$name" "$dest/contents/ui/$name"
    done
    mkdir -p "$XDG_CONFIG_HOME"
    cat >"$XDG_CONFIG_HOME/kwinrc" <<EOF
[org.kde.kdecoration2]
library=org.kde.kwin.aurorae
theme=$plugin_id

[org.kde.kwin.aurorae]
theme=$plugin_id

[Plugins]
blurEnabled=true
contrastEnabled=true
EOF
}

echo "Previewing $plugin_id from $theme_root"
echo "Edit $template_ui (QML overlay) or $theme_pkg (metrics, mask, images)."
echo "Close the nested window or press Ctrl+C to stop."

while true; do
    stage_package
    setsid kwin_wayland \
        --socket "quickxp-deco-$$" \
        --width 1100 \
        --height 720 \
        --no-lockscreen \
        --no-global-shortcuts \
        --no-kactivities \
        "$client_launch" &
    kwin_pid=$!

    inotifywait -q -r -e close_write,move,create,delete \
        --include '\.(qml|js|svg|json)$' \
        "$template_ui" "$theme_pkg" &
    watch_pid=$!

    set +e
    wait -n "$kwin_pid" "$watch_pid"
    set -e

    if ! kill -0 "$kwin_pid" 2>/dev/null; then
        echo "Nested KWin closed."
        kill "$watch_pid" 2>/dev/null || true
        wait "$watch_pid" 2>/dev/null || true
        wait "$kwin_pid" 2>/dev/null || true
        watch_pid=""
        kwin_pid=""
        break
    fi

    echo "Decoration sources changed; restarting preview."
    wait "$watch_pid" 2>/dev/null || true
    watch_pid=""
    kill -- "-$kwin_pid" 2>/dev/null || kill "$kwin_pid" 2>/dev/null || true
    wait "$kwin_pid" 2>/dev/null || true
    kwin_pid=""
    sleep 0.3
done

cleanup
