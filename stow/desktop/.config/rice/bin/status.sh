#!/usr/bin/env bash
# rice :: compact status blocks for tint2 executors
# Each block prints a few glyph lines to fit the 46px bar.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

function usage() {
    cat <<EOM

Desktop bar status.
usage: ${SCRIPT_NAME} [--engagement|--network|--system|--volume|--notifications|--battery|--help]

EOM
    exit 1
}

function main() {
    case "${1:-}" in
    --engagement) block_engagement ;;
    --network) block_network ;;
    --system) block_system ;;
    --volume) block_volume ;;
    --notifications) block_notifications ;;
    --battery) block_battery ;;
    -h | --help | "") usage ;;
    *)
        echo "Error: unknown block '$1'" >&2
        usage
        ;;
    esac
}

function span() {
    printf '<span foreground="%s">%s</span>\n' "$1" "$2"
}

function block_engagement() {
    local engagement target accent muted red
    accent=$(theme_get accent "#cba6f7")
    muted=$(theme_get muted "#6c7086")
    red=$(theme_get red "#f38ba8")

    engagement=$(state_get engagement "")
    target=$(state_get target "")

    if [ -n "$engagement" ]; then
        span "$accent" "󰯄"
    else
        span "$muted" "󰋣"
    fi

    if [ -n "$target" ]; then
        span "$red" ""
    else
        span "$muted" ""
    fi
}

function block_network() {
    local green muted yellow icon vpn
    green=$(theme_get green "#a6e3a1")
    yellow=$(theme_get yellow "#f9e2af")
    muted=$(theme_get muted "#6c7086")

    icon=$("$RICE_DIR/bin/network.sh" --icon 2>/dev/null)
    [ -z "$icon" ] && icon="󰖪"

    if [ "$(network_online)" = "yes" ]; then
        span "$green" "$icon"
    else
        span "$muted" "$icon"
    fi

    vpn=$("$RICE_DIR/bin/vpn.sh" --status 2>/dev/null)
    if [ "$vpn" != "off" ] && [ -n "$vpn" ]; then
        span "$yellow" "󰖂"
    else
        span "$muted" "󰖂"
    fi
}

function network_online() {
    if ip -4 route show default 2>/dev/null | grep -q .; then
        printf 'yes'
        return 0
    fi
    printf 'no'
}

function block_system() {
    local fg cpu mem temp
    fg=$(theme_get fg_dim "#a6adc8")

    cpu=$(cpu_usage)
    mem=$(free -m | awk '/^Mem:/ {printf "%d", $3 * 100 / $2}')
    temp=$(temperature)

    span "$fg" ""
    span "$fg" "${cpu}"
    span "$fg" "󰍛"
    span "$fg" "${mem}"
    if [ -n "$temp" ]; then
        span "$fg" "${temp}°"
    fi
}

function cpu_usage() {
    local prev_file="$STATE_DIR/cpu-prev" prev_total prev_idle
    local total idle diff_total diff_idle usage
    local -a fields

    read -r -a fields < <(grep -m1 '^cpu ' /proc/stat)
    total=0
    local value
    for value in "${fields[@]:1}"; do
        total=$((total + value))
    done
    idle=${fields[4]}

    if [ -r "$prev_file" ]; then
        read -r prev_total prev_idle <"$prev_file"
    else
        prev_total=0
        prev_idle=0
    fi
    printf '%s %s' "$total" "$idle" >"$prev_file"

    diff_total=$((total - prev_total))
    diff_idle=$((idle - prev_idle))
    if [ "$diff_total" -le 0 ]; then
        printf '0'
        return 0
    fi

    usage=$(((diff_total - diff_idle) * 100 / diff_total))
    printf '%d' "$usage"
}

function temperature() {
    local file value
    for file in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$file" ] || continue
        value=$(cat "$file" 2>/dev/null)
        if [ -n "$value" ] && [ "$value" -gt 1000 ] 2>/dev/null; then
            printf '%d' $((value / 1000))
            return 0
        fi
    done
    return 0
}

function block_volume() {
    local vol accent muted
    accent=$(theme_get accent "#cba6f7")
    muted=$(theme_get muted "#6c7086")

    vol=$("$RICE_DIR/bin/volume.sh" --get 2>/dev/null)
    [ -z "$vol" ] && vol=0

    if wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED; then
        span "$muted" "󰝟"
        return 0
    fi

    span "$accent" "$("$RICE_DIR/bin/volume.sh" --icon)"
    span "$accent" "$vol"
}

function block_notifications() {
    local count accent muted urgent
    accent=$(theme_get accent "#cba6f7")
    muted=$(theme_get muted "#6c7086")
    urgent=$(theme_get urgent "#f38ba8")

    if [ "$(dunstctl is-paused 2>/dev/null)" = "true" ]; then
        span "$urgent" "󰂛"
        return 0
    fi

    count=$("$RICE_DIR/bin/notifications.sh" --count 2>/dev/null)
    [ -z "$count" ] && count=0

    if [ "$count" -gt 0 ] 2>/dev/null; then
        span "$accent" "󰂚"
        span "$accent" "$count"
        return 0
    fi
    span "$muted" "󰂜"
}

function block_battery() {
    local level status icon color
    level=$("$RICE_DIR/bin/battery.sh" --get 2>/dev/null)
    [ -z "$level" ] && return 0

    status=$("$RICE_DIR/bin/battery.sh" --status 2>/dev/null)
    icon=$("$RICE_DIR/bin/battery.sh" --icon 2>/dev/null)

    if [ "$status" = "charging" ] || [ "$status" = "full" ]; then
        color=$(theme_get green "#a6e3a1")
    elif [ "$level" -le 15 ] 2>/dev/null; then
        color=$(theme_get urgent "#f38ba8")
    elif [ "$level" -le 35 ] 2>/dev/null; then
        color=$(theme_get yellow "#f9e2af")
    else
        color=$(theme_get fg_dim "#a6adc8")
    fi

    span "$color" "$icon"
    span "$color" "$level"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
