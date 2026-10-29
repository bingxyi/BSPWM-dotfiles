#!/usr/bin/env bash
# BSPWM-dotfiles :: laptop battery status
# On machines without a battery, every block is empty,
# so the bar hides the battery without reporting an error.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

ICONS_DISCHARGING=("󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹")
ICONS_CHARGING=("󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅" "󰂅")

function usage() {
    cat <<EOM

Battery status and warnings.
usage: ${SCRIPT_NAME} [--get|--status|--icon|--tooltip|--watch|--help]
    --get       Battery percentage
    --status    Charging state
    --icon      Status icon
    --tooltip   Battery level and state
    --watch     Warn at 20%, 10% and 5%

EOM
    exit 1
}

function main() {
    case "${1:---get}" in
    -g | --get) battery_level ;;
    -s | --status) battery_status ;;
    -i | --icon) battery_icon ;;
    -t | --tooltip) battery_tooltip ;;
    -w | --watch) watch_battery ;;
    -h | --help) usage ;;
    *)
        echo "Error: unknown option '$1'" >&2
        usage
        ;;
    esac
}

function battery_path() {
    local dir
    for dir in /sys/class/power_supply/BAT*; do
        [ -r "$dir/capacity" ] || continue
        printf '%s' "$dir"
        return 0
    done
    return 1
}

function battery_level() {
    local dir
    dir=$(battery_path) || return 0
    cat "$dir/capacity" 2>/dev/null
}

function battery_status() {
    local dir raw
    dir=$(battery_path) || {
        printf 'none'
        return 0
    }
    raw=$(cat "$dir/status" 2>/dev/null)
    case "$raw" in
    Charging) printf 'charging' ;;
    Full) printf 'full' ;;
    "Not charging") printf 'full' ;;
    *) printf 'discharging' ;;
    esac
}

function battery_icon() {
    local level status index
    level=$(battery_level)
    [ -z "$level" ] && return 0

    status=$(battery_status)
    index=$((level / 10))
    [ "$index" -gt 10 ] && index=10

    if [ "$status" = "charging" ] || [ "$status" = "full" ]; then
        printf '%s' "${ICONS_CHARGING[$index]}"
        return 0
    fi
    printf '%s' "${ICONS_DISCHARGING[$index]}"
}

function battery_tooltip() {
    local level status
    level=$(battery_level)
    [ -z "$level" ] && return 0
    status=$(battery_status)

    case "$status" in
    charging) printf 'battery %s%% — charging' "$level" ;;
    full) printf 'battery %s%% — Plugged in' "$level" ;;
    *) printf 'battery %s%% — discharging' "$level" ;;
    esac
}

function watch_battery() {
    local level status warned=""
    battery_path >/dev/null || exit 0

    while true; do
        level=$(battery_level)
        status=$(battery_status)

        if [ "$status" = "discharging" ] && [ -n "$level" ]; then
            if [ "$level" -le 5 ] && [ "$warned" != "5" ]; then
                notify "Critical battery" "${level}% — Save your work" \
                    battery-caution critical
                warned="5"
            elif [ "$level" -le 10 ] && [ "$warned" != "5" ] && [ "$warned" != "10" ]; then
                notify "Low battery" "${level}% remaining" battery-low critical
                warned="10"
            elif [ "$level" -le 20 ] && [ -z "$warned" ]; then
                notify "battery" "${level}% remaining" battery-low normal
                warned="20"
            fi
        else
            warned=""
        fi

        sleep 60
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
