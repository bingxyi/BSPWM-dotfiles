#!/usr/bin/env bash
# BSPWM-dotfiles :: Eww control center on the right of the primary monitor
#
# Animation needs two steps: create the window before sliding the revealer.
# Opening and revealing at once would show the full panel immediately.
# Use open -> brief delay -> reveal to preserve the transition.
#
# Works with either profile: start the Eww daemon on demand,
# including in Nyx, where tint2 provides the bar.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"


function usage() {
    cat <<EOM

Desktop control center.
usage: ${SCRIPT_NAME} [--toggle|--open|--close|--status|--glyph|--help]
    --glyph     Status icon for the bar

EOM
    exit 1
}

# The bar is always visible, so its glyph must show at a glance
# whether an inhibitor is keeping the system awake. DND has its own bell.
function print_glyph() {
    local caffeine color glyph
    caffeine=$("$OFFSEC_DIR/bin/caffeine.sh" --status 2>/dev/null)

    if [ "$caffeine" = "on" ]; then
        color=$(theme_get yellow '#c9a86a')
        glyph='\U000f0f8b'
    else
        color=$(theme_get fg_dim '#9c93b0')
        glyph='\U000f062e'
    fi
    printf '<span foreground="%s">%b</span>\n' "$color" "$glyph"
}

function main() {
    local action="toggle"

    while (($#)); do
        case $1 in
        -t | --toggle) action="toggle" ;;
        -o | --open) action="open" ;;
        -c | --close) action="close" ;;
        -s | --status) action="status" ;;
        -g | --glyph) action="glyph" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    glyph) print_glyph ;;
    *) exec "$HOME/.config/offsec/bin/panel.sh" "$action" control ;;
    esac

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
