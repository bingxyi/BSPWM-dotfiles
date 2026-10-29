#!/usr/bin/env bash
# offsec-dotfiles :: VPN do lab (OpenVPN/WireGuard) com status na barra

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

VPN_DIR="${OFFSEC_VPN_DIR:-$HOME/vpn}"

function usage() {
    cat <<EOM

Laboratory VPN connections.
usage: ${SCRIPT_NAME} [--menu|--up <file.ovpn>|--down|--status|--help]
Profile directory: ${VPN_DIR}

EOM
    exit 1
}

function main() {
    local action="menu" file=""

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -u | --up)
            shift
            file="$1"
            action="up"
            ;;
        -d | --down) action="down" ;;
        -s | --status) action="status" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    menu) menu_vpn ;;
    up) vpn_up "$file" ;;
    down) vpn_down ;;
    status) vpn_status ;;
    esac
}

function menu_vpn() {
    local chosen
    chosen=$( (
        find "$VPN_DIR" -maxdepth 2 -type f -name '*.ovpn' -printf '󰖂  %f\n' 2>/dev/null
        printf '󰖪  disconnect\n󰋼  status\n'
    ) | rofi -dmenu -i -p "vpn" -theme "$ROFI_MENU_THEME")
    [ -z "$chosen" ] && exit 0

    case "$chosen" in
    *disconnect*) vpn_down ;;
    *status*)
        notify "vpn" "$(vpn_status)" network-vpn
        ;;
    *)
        local name file
        name=${chosen#*  }
        file=$(find "$VPN_DIR" -maxdepth 2 -type f -name "$name" | head -n1)
        vpn_up "$file"
        ;;
    esac
}

function vpn_up() {
    local file="$1"
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "Error: Invalid .ovpn profile" >&2
        notify "vpn" "Profile not found" dialog-error critical
        exit 1
    fi
    exit_on_missing_tools openvpn

    kitty --class vpn --hold -e sudo openvpn --config "$file" &
    disown
    notify "vpn" "Connecting with $(basename "$file")" network-vpn
    (
        sleep 8
        refresh_bar
    ) &
}

function vpn_down() {
    sudo pkill -x openvpn 2>/dev/null
    sleep 1
    refresh_bar
    notify "vpn" "disconnected" network-offline
}

function vpn_status() {
    local ip
    ip=$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -n "$ip" ]; then
        printf '%s' "$ip"
        return 0
    fi
    printf 'off'
}

function refresh_bar() {
    if command -v eww &>/dev/null; then
        eww -c "$HOME/.config/eww" update vpn="$(vpn_status)" 2>/dev/null
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
