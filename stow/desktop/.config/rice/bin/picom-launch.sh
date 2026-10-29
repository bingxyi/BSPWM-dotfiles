#!/usr/bin/env bash
# Purpose: start picom with a configuration suited to the installed version.
#   picom >= 12 -> picom.conf       (native animations, "rules" syntax)
#   picom <  12 -> picom-basic.conf (no animations, legacy syntax)
# If the selected configuration fails, try the basic one before giving up.
# Usage: picom-launch.sh [--check]

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

LOG="$STATE_DIR/picom.log"
CONFIG_MODERN="$HOME/.config/picom/picom.conf"
CONFIG_BASIC="$HOME/.config/picom/picom-basic.conf"

function usage() {
    cat <<EOM

Start picom with a configuration supported by the installed version.
usage: ${SCRIPT_NAME} [--check|--help]
    --check   Report version and selected configuration

EOM
    exit 1
}

function main() {
    case "${1:-}" in
    -c | --check)
        report_choice
        exit 0
        ;;
    -h | --help) usage ;;
    "") ;;
    *)
        echo "Error: unknown option '$1'" >&2
        usage
        ;;
    esac

    if ! command -v picom &>/dev/null; then
        notify_user "picom not installed (pacman -S picom)" critical
        exit 1
    fi

    exec 9>"${XDG_RUNTIME_DIR:-$STATE_DIR}/rice-picom.lock"
    flock 9 || return 1
    pgrep -u "$UID" -x picom >/dev/null && return 0

    local config
    config=$(pick_config)

    if start_picom "$config"; then
        exit 0
    fi

    if [ "$config" != "$CONFIG_BASIC" ]; then
        notify_user "Modern configuration rejected — using picom-basic.conf" normal
        start_picom "$CONFIG_BASIC" && exit 0
    fi

    notify_user "picom failed to start; rode 'picom --config $config' to see the error" critical
    exit 1
}

function picom_major() {
    local raw
    raw=$(picom --version 2>/dev/null | head -n1)
    # Observed formats: "v12.5", "vgit-...", "picom v11.2".
    printf '%s' "$raw" | grep -oE 'v[0-9]+' | head -n1 | tr -d 'v'
}

function pick_config() {
    local major
    major=$(picom_major)

    if [ -n "$major" ] && [ "$major" -ge 12 ] 2>/dev/null && [ -r "$CONFIG_MODERN" ]; then
        printf '%s' "$CONFIG_MODERN"
        return 0
    fi
    printf '%s' "$CONFIG_BASIC"
}

function start_picom() {
    local config="$1" pid
    # picom writes startup warnings to stderr. Redirect them to a log
    # so they do not inherit the session stderr and appear on screen
    # immediately after login. Keep the log for troubleshooting.
    picom --config "$config" >"$LOG" 2>&1 9>&- &
    pid=$!
    sleep 2
    kill -0 "$pid" 2>/dev/null
}

function report_choice() {
    local major config
    major=$(picom_major)
    config=$(pick_config)

    printf 'picom installed ... %s\n' "$(picom --version 2>/dev/null | head -n1 || echo 'not found')"
    printf 'major version ...... %s\n' "${major:-unknown}"
    printf 'configuration ...... %s\n' "$config"
    if [ "$config" = "$CONFIG_BASIC" ]; then
        printf '\nNo animations: picom 12+ from the official repository supports them.\n'
        printf 'Update with: sudo pacman -S picom\n'
    fi
}

function notify_user() {
    command -v notify-send &>/dev/null || {
        echo "picom: $1" >&2
        return 0
    }
    notify-send -a archlinux -u "${2:-normal}" "picom" "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
