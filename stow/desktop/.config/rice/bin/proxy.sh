#!/usr/bin/env bash
# rice :: interception proxy (Burp/ZAP/mitmproxy) and related tools

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

PROXY_HOST="${RICE_PROXY_HOST:-127.0.0.1}"
PROXY_PORT="${RICE_PROXY_PORT:-8080}"

function usage() {
    cat <<EOM

Intercepting proxy and test browser.
usage: ${SCRIPT_NAME} [options]
    --menu      Open proxy menu
    --burp      Launch Burp Suite
    --zap       Launch OWASP ZAP
    --mitm      Launch mitmproxy
    --firefox   Open the rice Firefox profile
    --toggle    Enable/disable system proxy
    --cert      Install Burp CA certificate
    --status    Print up/down
    --help      Show this help

EOM
    exit 1
}

function main() {
    local action="menu"

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -b | --burp) action="burp" ;;
        -z | --zap) action="zap" ;;
        --mitm) action="mitm" ;;
        -f | --firefox) action="firefox" ;;
        -t | --toggle) action="toggle" ;;
        --cert) action="cert" ;;
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
    menu) menu_proxy ;;
    burp) start_burp ;;
    zap) start_zap ;;
    mitm) start_mitm ;;
    firefox) start_firefox ;;
    toggle) toggle_system_proxy ;;
    cert) install_burp_cert ;;
    status) proxy_status ;;
    esac
}

function menu_proxy() {
    local choice
    choice=$(printf '󱂇  Burp Suite\n󰀹  OWASP ZAP\n󰖟  Firefox (rice profile)\n󰆧  mitmproxy\n󰐥  System proxy (on/off)\n󰄤  install Burp CA\n' |
        rofi -dmenu -i -p "proxy" -theme "$ROFI_MENU_THEME" -lines 6)
    case "$choice" in
    *CA*) install_burp_cert ;;
    *Burp*) start_burp ;;
    *ZAP*) start_zap ;;
    *Firefox*) start_firefox ;;
    *mitmproxy*) start_mitm ;;
    *System*) toggle_system_proxy ;;
    esac
}

function start_burp() {
    local bin
    for bin in burpsuite burpsuite-pro BurpSuiteCommunity BurpSuitePro; do
        if command -v "$bin" &>/dev/null; then
            _JAVA_AWT_WM_NONREPARENTING=1 "$bin" >/dev/null 2>&1 &
            disown
            notify "burp" "starting ($bin)" security-high
            return 0
        fi
    done
    notify "burp" "Executable not found (AUR: burpsuite)" dialog-error critical
    return 1
}

function start_zap() {
    local bin
    for bin in zaproxy zap owasp-zap; do
        if command -v "$bin" &>/dev/null; then
            _JAVA_AWT_WM_NONREPARENTING=1 "$bin" >/dev/null 2>&1 &
            disown
            return 0
        fi
    done
    notify "zap" "Executable not found" dialog-error critical
    return 1
}

function start_mitm() {
    exit_on_missing_tools mitmproxy
    local path
    path=$(state_get engagement "$HOME")
    kitty --directory "$path" --class mitmproxy -e mitmproxy \
        --listen-port "$PROXY_PORT" &
    disown
}

function start_firefox() {
    exit_on_missing_tools firefox
    local profiles="$HOME/.mozilla/firefox/profiles.ini"

    if [ -r "$profiles" ] && grep -q '^Name=rice$' "$profiles"; then
        firefox -P rice --no-remote >/dev/null 2>&1 &
        disown
        notify "firefox" "rice profile ($PROXY_HOST:$PROXY_PORT)" firefox low
        return 0
    fi

    firefox >/dev/null 2>&1 &
    disown
    notify "firefox" "The rice profile does not exist — create it with: firefox -P" \
        dialog-warning normal
}

function toggle_system_proxy() {
    local current
    current=$(state_get proxy "off")

    if [ "$current" = "on" ]; then
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.system.proxy mode 'none' 2>/dev/null
        fi
        state_set proxy "off"
        notify "proxy" "disabled" network-offline
    else
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.system.proxy mode 'manual' 2>/dev/null
            gsettings set org.gnome.system.proxy.http host "$PROXY_HOST" 2>/dev/null
            gsettings set org.gnome.system.proxy.http port "$PROXY_PORT" 2>/dev/null
            gsettings set org.gnome.system.proxy.https host "$PROXY_HOST" 2>/dev/null
            gsettings set org.gnome.system.proxy.https port "$PROXY_PORT" 2>/dev/null
        fi
        state_set proxy "on"
        notify "proxy" "$PROXY_HOST:$PROXY_PORT Enabled for GTK apps" security-medium
    fi
    return 0
}

function install_burp_cert() {
    local tmp="/tmp/burp-ca.der" pem="/tmp/burp-ca.crt"

    if ! proxy_listening; then
        notify "Burp CA" "Start the proxy at $PROXY_HOST:$PROXY_PORT first" \
            dialog-error critical
        exit 1
    fi
    if ! curl -s --proxy "$PROXY_HOST:$PROXY_PORT" http://burp/cert -o "$tmp"; then
        notify "Burp CA" "download failed" dialog-error critical
        exit 1
    fi
    if ! openssl x509 -inform DER -in "$tmp" -out "$pem"; then
        notify "Burp CA" "DER->PEM conversion failed" dialog-error critical
        exit 1
    fi

    kitty --hold -e bash -c \
        "sudo cp '$pem' /etc/ca-certificates/trust-source/anchors/burp-ca.crt && sudo trust extract-compat && echo 'CA installed. Restart the browser.'" &
    disown
}

function proxy_listening() {
    ss -ltn 2>/dev/null | grep -q ":${PROXY_PORT}\b"
}

function proxy_status() {
    if proxy_listening; then
        printf 'up'
        return 0
    fi
    printf 'down'
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
