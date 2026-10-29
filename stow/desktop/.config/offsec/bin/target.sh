#!/usr/bin/env bash
# offsec-dotfiles :: alvo ativo — aparece na barra, no prompt e vira variável $TARGET

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

function usage() {
    cat <<EOM

Manage the active target.
usage: ${SCRIPT_NAME} [--menu|--set <target>|--get|--clear|--copy|--help]

EOM
    exit 1
}

function main() {
    local action="menu" value=""

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -s | --set)
            shift
            value="$1"
            action="set"
            ;;
        -g | --get) action="get" ;;
        -c | --clear) action="clear" ;;
        --copy) action="copy" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    menu) menu_target ;;
    set) set_target "$value" ;;
    get) state_get target "" && echo ;;
    clear) clear_target ;;
    copy) copy_target ;;
    esac
}

function menu_target() {
    local current choice
    current=$(state_get target "none")
    choice=$(printf '󰗇  Set target\n󰅍  Copy target (%s)\n󰑓  Open in browser\n󰈲  Quick nmap\n󰅖  Clear target\n' "$current" |
        rofi -dmenu -i -p "target" -theme "$ROFI_MENU_THEME" -lines 5)
    case "$choice" in
    *"Set target"*) set_target "$(rofi_input "target" "host, IP or URL")" ;;
    *"Copy target"*) copy_target ;;
    *browser*) open_browser ;;
    *nmap*) quick_scan ;;
    *"Clear target"*) clear_target ;;
    esac
}

function set_target() {
    local value="$1"
    [ -z "$value" ] && exit 0

    state_set target "$value"
    persist_in_engagement "$value"
    refresh_bar
    notify "Target set" "$value" network-server
}

function persist_in_engagement() {
    local value="$1" path
    path=$(state_get engagement "")
    [ -d "$path" ] || return 0

    if [ -f "$path/.offsec" ]; then
        sed -i "s|^target=.*|target=${value}|" "$path/.offsec"
        return 0
    fi
    printf 'target=%s\n' "$value" >"$path/.offsec"
}

function clear_target() {
    state_clear target
    refresh_bar
    notify "target" "cleared" network-offline low
}

function copy_target() {
    local value
    value=$(state_get target "")
    [ -z "$value" ] && exit 0
    printf '%s' "$value" | xclip -selection clipboard
    notify "Target copied" "$value" edit-copy low
}

function open_browser() {
    local value
    value=$(state_get target "")
    [ -z "$value" ] && exit 0
    case "$value" in
    http://* | https://*) xdg-open "$value" ;;
    *) xdg-open "http://$value" ;;
    esac
}

function quick_scan() {
    local value path out
    value=$(state_get target "")
    [ -z "$value" ] && exit 0

    path=$(state_get engagement "$HOME")
    out="$path/scans"
    mkdir -p "$out"

    kitty --hold -e bash -c \
        "nmap -Pn -sV --top-ports 1000 -oA '$out/nmap-quick-$(date +%H%M)' '$value'" &
    disown
}

function refresh_bar() {
    if command -v eww &>/dev/null; then
        eww -c "$HOME/.config/eww" update target="$(state_get target 'No target')" 2>/dev/null
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
