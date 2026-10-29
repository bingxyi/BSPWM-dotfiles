#!/usr/bin/env bash
# rice :: emit workspaces as JSON for Eww (deflisten)
# React to each bspwm event without renaming desktops. Read the names
# assigned by monitors.sh and map each position to a role icon.

ICONS=("" "󰈹" "" "" "" "󰛳" "󰠮" "󰝚" "󰢹" "󰀻")
ROLES=("terminal" "web" "proxy/burp" "code" "files" "network" "notes" "media" "vm/remote" "miscellaneous")

function main() {
    emit
    bspc subscribe desktop node_add node_remove node_transfer node_flag desktop_focus monitor_focus |
        while read -r _; do
            emit
        done
}

function emit() {
    local focused i name state icon role first=1
    local -a names

    mapfile -t names < <(bspc query -D --names 2>/dev/null)
    focused=$(bspc query -D -d focused --names 2>/dev/null)

    printf '['
    for i in "${!names[@]}"; do
        name="${names[$i]}"
        icon="${ICONS[$i]:-󰀻}"
        role="${ROLES[$i]:-workspace}"

        if [ "$name" = "$focused" ]; then
            state="focused"
        elif [ -n "$(bspc query -N -d "$name" -n .urgent 2>/dev/null | head -n1)" ]; then
            state="urgent"
        elif [ -n "$(bspc query -N -d "$name" -n .window 2>/dev/null | head -n1)" ]; then
            state="occupied"
        else
            state="free"
        fi

        [ "$first" -eq 0 ] && printf ','
        first=0
        printf '{"name":"%s","icon":"%s","role":"%s","state":"%s"}' \
            "$name" "$icon" "$role" "$state"
    done
    printf ']\n'
}

main "$@"
