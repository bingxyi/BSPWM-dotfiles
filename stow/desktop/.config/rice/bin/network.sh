#!/usr/bin/env bash
# rice :: network menu (nmcli) and bar status

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

function usage() {
    cat <<EOM

Network connection menu and status.
usage: ${SCRIPT_NAME} [--menu|--status|--icon|--wifi-state|--wifi-name|--wifi-toggle|--help]
    --wifi-state    Print on/off
    --wifi-name     Print the connected SSID
    --wifi-toggle   Enable/disable Wi-Fi

EOM
    exit 1
}

function main() {
    local action="menu"

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -s | --status) action="status" ;;
        --icon) action="icon" ;;
        --wifi-state) action="wifi-state" ;;
        --wifi-name) action="wifi-name" ;;
        --wifi-toggle) action="wifi-toggle" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    exit_on_missing_tools nmcli

    case "$action" in
    menu) menu_network ;;
    status) print_status ;;
    icon) print_icon ;;
    wifi-state) wifi_state ;;
    wifi-name) wifi_name ;;
    wifi-toggle) wifi_toggle ;;
    esac
}

function menu_network() {
    exit_on_missing_tools rofi
    local chosen ssid
    chosen=$( (
        printf '󰤨  Rescan\n󰖪  Disable Wi-Fi\n󰤥  Enable Wi-Fi\n󰒓  Connection editor\n───────────────\n'
        nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list |
            awk -F: '$2 != "" { mark = ($1 == "*") ? "󰸞" : " "; printf "%s %s  (%s%%, %s)\n", mark, $2, $3, ($4 == "" ? "open" : $4) }'
    ) | rofi -dmenu -i -p "network" -theme "$ROFI_MENU_THEME")
    [ -z "$chosen" ] && exit 0

    case "$chosen" in
    *Rescan*)
        nmcli device wifi rescan
        sleep 2
        menu_network
        ;;
    *"Disable Wi-Fi"*) nmcli radio wifi off ;;
    *"Enable Wi-Fi"*) nmcli radio wifi on ;;
    *editor*) nm-connection-editor & ;;
    ────*) exit 0 ;;
    *)
        ssid=$(printf '%s' "$chosen" | sed -e 's/^[^ ]* //' -e 's/  (.*//')
        connect_wifi "$ssid"
        ;;
    esac
}

function connect_wifi() {
    local ssid="$1" password
    [ -z "$ssid" ] && exit 0

    if nmcli -t -f NAME connection show | grep -qx "$ssid"; then
        nmcli connection up id "$ssid" >/dev/null 2>&1 &&
            notify "network" "Connected to $ssid" network-wireless && exit 0
    fi

    password=$(rofi -dmenu -password -p "Password for $ssid" -theme "$ROFI_MENU_THEME" -lines 0)
    if [ -z "$password" ]; then
        nmcli device wifi connect "$ssid" >/dev/null 2>&1
    else
        nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1
    fi

    if [ $? -eq 0 ]; then
        notify "network" "Connected to $ssid" network-wireless
    else
        notify "network" "Failed to connect to $ssid" network-error critical
    fi
}

function wifi_state() {
    case "$(nmcli radio wifi 2>/dev/null)" in
    enabled) printf 'on' ;;
    *) printf 'off' ;;
    esac
}

# Wi-Fi card label in the control center: distinguish radio off,
# radio on without an association, and the connected SSID.
function wifi_name() {
    if [ "$(wifi_state)" = "off" ]; then
        printf 'disabled'
        return 0
    fi
    local ssid
    # Read cached results; opening the control center must not trigger a Wi-Fi scan.
    ssid=$(nmcli -t -f ACTIVE,SSID device wifi list --rescan no 2>/dev/null |
        awk -F: '$1 == "yes" { print $2; exit }')
    if [ -n "$ssid" ]; then
        printf '%s' "$ssid"
        return 0
    fi
    printf 'No network'
}

function wifi_toggle() {
    if [ "$(wifi_state)" = "on" ]; then
        nmcli radio wifi off 2>/dev/null
        notify "Wi-Fi" "Radio disabled" network-wireless-offline low
    else
        nmcli radio wifi on 2>/dev/null
        notify "Wi-Fi" "Radio enabled" network-wireless low
    fi
    command -v eww >/dev/null 2>&1 && eww -c "$HOME/.config/eww" update \
        wifi_state="$(wifi_state)" wifi_name="$(wifi_name)" 2>/dev/null
    return 0
}

function print_status() {
    local conn
    conn=$(nmcli -t -f NAME,TYPE connection show --active |
        awk -F: '$2 != "loopback" {print $1; exit}')
    if [ -z "$conn" ]; then
        printf 'offline'
        return 0
    fi
    printf '%s' "$conn"
}

function print_icon() {
    local type
    type=$(nmcli -t -f TYPE connection show --active | head -n1)
    case "$type" in
    *wireless*) printf '󰖩' ;;
    *ethernet*) printf '󰈀' ;;
    *) printf '󰖪' ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
