#!/usr/bin/env bash
# BSPWM-dotfiles :: volume with OSD (wpctl/PipeWire)

DEPENDENCIES=(wpctl)
SCRIPT_NAME=${0##*/}
SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"
STEP="0.05"

function usage() {
    cat <<EOM

Volume and notification progress bar.
usage: ${SCRIPT_NAME} [--up|--down|--toggle|--mic-toggle|--set <0-100>|--get|--icon|--help]
    --up/--down    Adjust by 5%
    --toggle       Toggle mute
    --mic-toggle   Toggle microphone mute

EOM
    exit 1
}

function main() {
    local action="get" value=""

    while (($#)); do
        case $1 in
        -u | --up) action="up" ;;
        -d | --down) action="down" ;;
        -t | --toggle) action="toggle" ;;
        -m | --mic-toggle) action="mic" ;;
        -s | --set)
            shift
            value="$1"
            action="set"
            ;;
        -g | --get) action="get" ;;
        --icon) action="icon" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    exit_on_missing_tools "${DEPENDENCIES[@]}"

    case "$action" in
    up)
        wpctl set-mute "$SINK" 0
        wpctl set-volume -l 1.5 "$SINK" "${STEP}+"
        osd
        ;;
    down)
        wpctl set-volume "$SINK" "${STEP}-"
        osd
        ;;
    toggle)
        wpctl set-mute "$SINK" toggle
        osd
        ;;
    mic)
        wpctl set-mute "$SOURCE" toggle
        if is_muted "$SOURCE"; then
            notify_osd "microphone" "muted" microphone-sensitivity-muted
        else
            notify_osd "microphone" "active" microphone-sensitivity-high
        fi
        ;;
    set) set_volume "$value" ;;
    get) get_volume ;;
    icon) volume_icon ;;
    esac
}

function set_volume() {
    local value="$1"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: --set expects a number between 0 and 100" >&2
        exit 1
    fi
    [ "$value" -gt 100 ] && value=100
    wpctl set-mute "$SINK" 0
    wpctl set-volume "$SINK" "${value}%"
    refresh_bar
}

function get_volume() {
    local raw
    raw=$(wpctl get-volume "$SINK" 2>/dev/null)
    if [ -z "$raw" ]; then
        echo 0
        return 1
    fi
    awk '{ printf "%d", $2 * 100 }' <<<"$raw"
}

function is_muted() {
    wpctl get-volume "${1:-$SINK}" 2>/dev/null | grep -q MUTED
}

function volume_icon() {
    local vol
    vol=$(get_volume)
    if is_muted; then
        printf '󰝟'
        return 0
    fi
    if [ "$vol" -eq 0 ]; then
        printf '󰕿'
    elif [ "$vol" -lt 50 ]; then
        printf '󰖀'
    else
        printf '󰕾'
    fi
}

function osd() {
    local vol
    vol=$(get_volume)
    if is_muted; then
        notify_osd "volume" "muted" audio-volume-muted 0
        return 0
    fi
    notify_osd "volume" "${vol}%" audio-volume-high "$vol"
    refresh_bar
}

function notify_osd() {
    local title="$1" body="$2" icon="$3" progress="${4:-}"
    if [ -n "$progress" ]; then
        notify-send -a archlinux -u low -i "$icon" -h "int:value:$progress" \
            -h string:x-dunst-stack-tag:osd "$title" "$body"
        return 0
    fi
    notify-send -a archlinux -u low -i "$icon" \
        -h string:x-dunst-stack-tag:osd "$title" "$body"
}

function refresh_bar() {
    if command -v eww &>/dev/null; then
        eww -c "$HOME/.config/eww" update volume="$(get_volume)" 2>/dev/null
    fi
    return 0
}

function exit_on_missing_tools() {
    local cmd
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null && continue
        printf "Error: tool '%s' not found\n" "$cmd" >&2
        exit 1
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
