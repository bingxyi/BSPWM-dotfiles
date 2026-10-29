#!/usr/bin/env bash
# offsec-dotfiles :: alterna entre os dois dotfiles (Nyx e Vesper) sem relogar

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

function usage() {
    cat <<EOM

Select the desktop bar profile.
usage: ${SCRIPT_NAME} [--menu|--set <nyx|vesper>|--current|--help]
    nyx       Vertical tint2 panel
    vesper    Eww bar and panels

EOM
    exit 1
}

function main() {
    local action="menu" profile=""

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -s | --set)
            shift
            profile="$1"
            action="set"
            ;;
        -c | --current) action="current" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    menu) menu_profile ;;
    set) set_profile "$profile" ;;
    current) active_profile && echo ;;
    esac
}

function menu_profile() {
    local chosen
    chosen=$(printf '󰄛  nyx    (tint2 — Light and direct)\n󰧨  vesper (eww — Panels and widgets)\n' |
        rofi -dmenu -i -p "profile" -theme "$ROFI_MENU_THEME" -lines 2)
    [ -z "$chosen" ] && exit 0
    case "$chosen" in
    *nyx*) set_profile nyx ;;
    *vesper*) set_profile vesper ;;
    esac
}

function set_profile() {
    local profile="$1"
    case "$profile" in
    nyx | vesper) ;;
    *)
        echo "Error: invalid profile '$profile' (use nyx or vesper)" >&2
        exit 1
        ;;
    esac

    printf '%s' "$profile" >"$OFFSEC_DIR/profile"

    local width=46
    [ "$profile" = "vesper" ] && width=54

    local monitor m
    monitor=$(xrandr --query | awk '/ connected primary/ {print $1; exit}')
    for m in $(bspc query -M --names); do
        if [ "$m" = "$monitor" ]; then
            bspc config -m "$m" left_padding "$width"
        else
            bspc config -m "$m" left_padding 0
        fi
    done

    "$OFFSEC_DIR/bin/bar.sh" --restart
    notify "profile" "$profile active" preferences-desktop-theme
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
