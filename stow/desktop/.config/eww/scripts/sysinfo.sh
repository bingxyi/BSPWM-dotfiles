#!/usr/bin/env bash
# BSPWM-dotfiles :: compact metrics for the Vesper bar

STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/offsec"
mkdir -p "$STATE_DIR"

function cpu_usage() {
    local prev_file="$STATE_DIR/cpu-prev-eww" prev_total=0 prev_idle=0
    local total=0 idle diff_total diff_idle value
    local -a fields

    read -r -a fields < <(grep -m1 '^cpu ' /proc/stat)
    for value in "${fields[@]:1}"; do
        total=$((total + value))
    done
    idle=${fields[4]}

    [ -r "$prev_file" ] && read -r prev_total prev_idle <"$prev_file"
    printf '%s %s' "$total" "$idle" >"$prev_file"

    diff_total=$((total - prev_total))
    diff_idle=$((idle - prev_idle))
    if [ "$diff_total" -le 0 ]; then
        printf '0'
        return 0
    fi
    printf '%d' $(((diff_total - diff_idle) * 100 / diff_total))
}

function mem_usage() {
    free -m | awk '/^Mem:/ {printf "%d", $3 * 100 / $2}'
}

function temperature() {
    local file value
    for file in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$file" ] || continue
        value=$(cat "$file" 2>/dev/null)
        if [ -n "$value" ] && [ "$value" -gt 1000 ] 2>/dev/null; then
            printf '%d°' $((value / 1000))
            return 0
        fi
    done
    printf ''
}

case "${1:-}" in
--cpu) cpu_usage ;;
--mem) mem_usage ;;
--temp) temperature ;;
*)
    echo "usage: $(basename "$0") --cpu|--mem|--temp" >&2
    exit 1
    ;;
esac
