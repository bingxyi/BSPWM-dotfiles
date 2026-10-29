#!/usr/bin/env bash
# BSPWM-dotfiles :: notification center

DEPENDENCIES=(dunstctl)
SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

LOG="$STATE_DIR/notifications.json"

function usage() {
    cat <<EOM

Notification center and history.
usage: ${SCRIPT_NAME} [--toggle|--list|--clear|--dnd|--count|--status|--restore|--help]
    --toggle    Open/close the control center
    --list      Open history in rofi
    --clear     Clear history and visible notifications
    --dnd       Toggle Do not disturb
    --count     Print the history count

EOM
    exit 1
}

function main() {
    local action="toggle"

    while (($#)); do
        case $1 in
        -t | --toggle) action="toggle" ;;
        -l | --list) action="list" ;;
        -c | --clear) action="clear" ;;
        -d | --dnd) action="dnd" ;;
        --restore) action="restore" ;;
        --count) action="count" ;;
        --status) action="status" ;;
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
    toggle) toggle_center ;;
    list) list_rofi ;;
    clear) clear_all ;;
    dnd) toggle_dnd ;;
    restore)
        local saved
        saved=$(state_get dnd_enabled '')
        case "$saved" in
        true|false) dunstctl set-paused "$saved" ;;
        *) saved=$(dunstctl is-paused) && state_set dnd_enabled "$saved" ;;
        esac
        ;;
    count) count_notifications ;;
    status) print_status ;;
    esac
}

# Both profiles host notifications in the control center, so toggling opens
# the Eww panel whenever Eww is available.
# Use the rofi list as a fallback when Eww is not installed.
function toggle_center() {
    if command -v eww &>/dev/null && [ -x "$OFFSEC_DIR/bin/control.sh" ]; then
        "$OFFSEC_DIR/bin/control.sh" --toggle
        return $?
    fi
    list_rofi
}

function list_rofi() {
    exit_on_missing_tools rofi jq
    local chosen
    chosen=$(build_list | rofi -dmenu -i -p "notifications" \
        -theme "$ROFI_MENU_THEME" \
        -theme-str 'window {width: 45%;} listview {lines: 12;}')
    case "$chosen" in
    *"Clear history"*) clear_all ;;
    *"Do not disturb"*) toggle_dnd ;;
    esac
}

function build_list() {
    if [ -s "$LOG" ]; then
        tac "$LOG" | jq -r '"\(.time)  \(.summary)  —  \(.body|gsub("\n";" ")|.[0:60])"'
    else
        echo "󰂚  No notifications in history"
    fi
    echo "───────────────"
    echo "󰆴  Clear history"
    echo "󰂛  Toggle Do not disturb"
}

function clear_all() {
    dunstctl close-all 2>/dev/null
    dunstctl history-clear 2>/dev/null
    # Share the writer lock to avoid losing a newly received notification.
    (
        exec 8>"$STATE_DIR/notifications.lock"
        flock 8
        : >"$LOG"
    )
    refresh_bar
}

function toggle_dnd() {
    if [ "$(dunstctl is-paused)" = "true" ]; then
        dunstctl set-paused false || return 1
        state_set dnd_enabled false
        notify "notifications" "Normal mode" notification low
    else
        dunstctl set-paused true || return 1
        state_set dnd_enabled true
    fi
    refresh_bar
}

function count_notifications() {
    if [ -s "$LOG" ]; then
        grep -c '' "$LOG"
        return 0
    fi
    echo 0
}

function print_status() {
    if [ "$(dunstctl is-paused 2>/dev/null)" = "true" ]; then
        echo "dnd"
        return 0
    fi
    echo "on"
}

function refresh_bar() {
    command -v eww &>/dev/null && eww -c "$HOME/.config/eww" update \
        notif_count="$(count_notifications)" 2>/dev/null
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
