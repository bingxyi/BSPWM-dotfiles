#!/usr/bin/env bash
# BSPWM-dotfiles :: Nyx workspace column (tint2 executor)
# Always print exactly ten lines (execp_continuous = 10), one per workspace,
# with an icon for its role in the AppSec workflow.
# Do not rename desktops; monitors.sh owns their names.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

ICONS=("󰞷" "󰈹" "󰯄" "󰅴" "󰉋" "󰅩" "󰠮" "󰝚" "󰢹" "󰀻")
# Use Material Design glyphs (U+F0xxx); legacy Font Awesome glyphs
# (U+F0xx–U+F2xx) render blank in this JetBrainsMono Nerd Font build.
LABELS=("terminal" "web" "proxy/burp" "code" "files" "network" "notes" "media" "vm/remote" "miscellaneous")

function usage() {
    cat <<EOM

Workspace column and selector.
usage: ${SCRIPT_NAME} [--menu|--once|--help]
With no option, redraw on each bspwm event.

EOM
    exit 1
}

function main() {
    case "${1:-}" in
    --once)
        render
        exit 0
        ;;
    --menu)
        menu_workspaces
        exit 0
        ;;
    -h | --help) usage ;;
    "") ;;
    *)
        echo "Error: unknown option '$1'" >&2
        usage
        ;;
    esac

    render
    bspc subscribe desktop node_add node_remove node_transfer desktop_focus monitor_focus |
        while read -r _; do
            render
        done
}

function render() {
    local focused_col occupied_col free_col urgent_col
    focused_col=$(theme_get accent "#cba6f7")
    occupied_col=$(theme_get fg "#cdd6f4")
    free_col=$(theme_get muted "#6c7086")
    urgent_col=$(theme_get urgent "#f38ba8")

    local -a names
    mapfile -t names < <(bspc query -D --names 2>/dev/null)

    local focused
    focused=$(bspc query -D -d focused --names 2>/dev/null)

    local i name color icon
    for i in $(seq 0 9); do
        name="${names[$i]:-}"
        icon="${ICONS[$i]}"

        if [ -z "$name" ]; then
            printf '\n'
            continue
        fi

        if [ "$name" = "$focused" ]; then
            color="$focused_col"
        elif is_urgent "$name"; then
            color="$urgent_col"
        elif is_occupied "$name"; then
            color="$occupied_col"
        else
            color="$free_col"
        fi

        # Color alone is insufficient on a narrow panel: make the focused workspace
        # larger and bolder, and shrink empty workspaces.
        local size weight
        if [ "$name" = "$focused" ]; then
            size="x-large"
            weight="bold"
        elif is_occupied "$name"; then
            size="medium"
            weight="normal"
        else
            size="small"
            weight="normal"
        fi

        printf '<span foreground="%s" size="%s" weight="%s">%s</span>\n' \
            "$color" "$size" "$weight" "$icon"
    done
}

function is_occupied() {
    [ -n "$(bspc query -N -d "$1" -n .window 2>/dev/null | head -n1)" ]
}

function is_urgent() {
    [ -n "$(bspc query -N -d "$1" -n .urgent 2>/dev/null | head -n1)" ]
}

function menu_workspaces() {
    local -a names
    mapfile -t names < <(bspc query -D --names 2>/dev/null)

    local i chosen index
    chosen=$(
        for i in $(seq 0 $((${#names[@]} - 1))); do
            printf '%s  %s  —  %s\n' "${ICONS[$i]:-󰀻}" "${names[$i]}" "${LABELS[$i]:-workspace}"
        done | rofi -dmenu -i -p "workspace" -theme "$ROFI_MENU_THEME" -lines 10
    )
    [ -z "$chosen" ] && exit 0

    index=$(printf '%s' "$chosen" | awk '{print $2}')
    bspc desktop -f "$index"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
