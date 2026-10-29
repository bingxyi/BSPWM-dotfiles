#!/usr/bin/env bash
# BSPWM-dotfiles :: power menu with confirmation

DEPENDENCIES=(rofi systemctl)
SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

function usage() {
    cat <<EOM

Session and power menu: lock, log out, suspend, restart, power off.
usage: ${SCRIPT_NAME} [--help]

EOM
    exit 1
}

function main() {
    while (($#)); do
        case $1 in
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    exit_on_missing_tools "${DEPENDENCIES[@]}"

    local choice
    choice=$(printf '󰌾  lock\n󰗽  Log out\n󰒲  suspend\n󰜉  restart\n󰐥  power off\n' |
        rofi -dmenu -i -p "session" -theme "$HOME/.config/rofi/themes/power.rasi")
    [ -z "$choice" ] && exit 0

    case "$choice" in
    *lock*) "$OFFSEC_DIR/bin/lock.sh" ;;
    *"Log out"*) confirm_and_run "Log out?" "bspc quit" ;;
    *suspend*) run_suspend ;;
    *restart*) confirm_and_run "restart?" "systemctl reboot" ;;
    *"power off"*) confirm_and_run "power off?" "systemctl poweroff" ;;
    esac
}

function confirm_and_run() {
    local question="$1" command="$2"
    if rofi_confirm "$question"; then
        eval "$command"
    fi
}

function run_suspend() {
    "$OFFSEC_DIR/bin/lock.sh" &
    sleep 1
    systemctl suspend
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
