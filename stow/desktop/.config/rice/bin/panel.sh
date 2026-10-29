#!/usr/bin/env bash
# Shared popup lifetime: serialized switching, outside click, temporary Escape.
set -u
CONFIG="${RICE_EWW_CONFIG:-$HOME/.config/eww}"
RUNTIME="${XDG_RUNTIME_DIR:-$HOME/.cache/rice}"
mkdir -p "$RUNTIME"
KEY_PID="$RUNTIME/rice-popup-keys.pid"
KEY_CONFIG="$HOME/.config/rice/popup-keys.sxhkd"
ew() { eww -c "$CONFIG" "$@"; }
active() { ew active-windows 2>/dev/null; }
stop_keys() {
    local pid cmd
    if [[ -r "$KEY_PID" ]] && read -r pid < "$KEY_PID" && [[ "$pid" =~ ^[0-9]+$ ]]; then
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) || cmd=''
        [[ "$cmd" == *"sxhkd -c $KEY_CONFIG"* ]] && kill "$pid" 2>/dev/null || true
    fi
    rm -f "$KEY_PID"
}
close_panels() {
    local windows ids=()
    if (($#)); then windows="$1"; else windows=$(active); fi
    ew update cc_reveal=false media_reveal=false cc_visible=false >/dev/null 2>&1 || true
    if [[ "$windows" == *'control:'* || "$windows" == *'media:'* ]]; then
        sleep 0.24
    fi
    while IFS=: read -r id _; do
        case "$id" in control|media|cc_backdrop_*) ids+=("$id");; esac
    done <<< "$windows"
    ((${#ids[@]})) && ew close "${ids[@]}" >/dev/null 2>&1
    stop_keys
    return 0
}
action="${1:-toggle}"; window="${2:-control}"
[[ "$window" == control || "$window" == media ]] || exit 2
case "$action" in
status) active | grep -q "^$window:" && echo open || echo closed; exit 0;;
open|toggle|close|close-all) ;;
*) exit 2;;
esac
exec 9>"$RUNTIME/rice-popup.lock"
# Wait briefly so Escape/clicks during the opening frame are not lost.
flock -w 2 9 || exit 0
if [[ "$action" == close || "$action" == close-all ]]; then
    close_panels
    [[ "$action" == close-all ]] && ew close-all >/dev/null 2>&1
    exit 0
fi
if ! windows=$(active); then
    ew daemon 9>&- >/dev/null 2>&1
    for ((i=0;i<20;i++)); do ew ping >/dev/null 2>&1 && break; sleep 0.05; done
    windows=$(active) || { stop_keys; exit 1; }
fi
if [[ "$action" == toggle ]] && grep -q "^$window:" <<< "$windows"; then
    close_panels "$windows"; exit 0
fi
close_panels "$windows"
monitors=$(xrandr --listmonitors)
mapfile -t screens < <(awk '/^ *[0-9]+:/ {gsub(":","",$1); print $1}' <<< "$monitors")
primary=$(awk '/^ *[0-9]+: \+\*/ {gsub(":","",$1); print $1; exit}' <<< "$monitors")
for screen in "${screens[@]}"; do
    ew open cc_backdrop --id "cc_backdrop_$screen" --screen "$screen" || { close_panels; exit 1; }
done
sxhkd -c "$KEY_CONFIG" </dev/null >"$RUNTIME/rice-popup-keys.log" 2>&1 9>&- &
printf '%s\n' "$!" > "$KEY_PID"
if ! ew open "$window" --screen "${primary:-0}"; then close_panels; exit 1; fi
# The wm-ignore window must map after its backdrops and stay above them.
sleep 0.02
if [[ "$window" == control ]]; then
    ew update cc_visible=true cc_reveal=true
else
    ew update media_reveal=true
fi
