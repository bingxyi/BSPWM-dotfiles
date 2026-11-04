#!/usr/bin/env bash
# rice :: Nyx workspace column (tint2 executor)
# Always print exactly ten lines (execp_continuous = 10), one per workspace,
# with an icon for its role in the AppSec workflow.
# Do not rename desktops; monitors.sh owns their names.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

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

    exec "$RICE_DIR/bin/workspace_state.py" --tint2 --watch
}

function render() {
    "$RICE_DIR/bin/workspace_state.py" --tint2
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
    "$RICE_DIR/bin/workspace.sh" --focus "$index"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
