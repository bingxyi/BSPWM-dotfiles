#!/usr/bin/env bash
# rice :: keep the system awake (disable automatic locking/blanking)
#
# Two layers cover different idle paths:
#   X11 — "xset s off -dpms" disables the screensaver and display power saving
#   systemd — systemd-inhibit holds an idle/sleep lock while running
#
# The preference persists; the PID tracks only this session's inhibitor.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

PIDFILE="$STATE_DIR/caffeine.pid"

function usage() {
    cat <<EOM

Keep the screen on and prevent automatic locking.
usage: ${SCRIPT_NAME} [--toggle|--on|--off|--status|--icon|--restore|--help]
    --restore   Restore the saved preference at login

EOM
    exit 1
}

function is_on() {
    local pid
    [ -r "$PIDFILE" ] || return 1
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    # Require a live PID that still belongs to our inhibitor; reject recycled PIDs.
    kill -0 "$pid" 2>/dev/null || { rm -f "$PIDFILE"; return 1; }
    grep -qaF 'Caffeine mode active' "/proc/$pid/cmdline" 2>/dev/null || { rm -f "$PIDFILE"; return 1; }
    return 0
}

function caffeine_on() {
    if is_on; then
        xset s off -dpms || return 1
        state_set caffeine_enabled on
        return 0
    fi

    if [ -n "${DISPLAY:-}" ] && command -v xset >/dev/null 2>&1; then
        xset s off -dpms || return 1
    fi

    if command -v systemd-inhibit >/dev/null 2>&1; then
        setsid systemd-inhibit \
            --what=idle:sleep \
            --who=archlinux \
            --why="Caffeine mode active" \
            --mode=block \
            sleep infinity >/dev/null 2>&1 &
        printf '%s' "$!" >"$PIDFILE"
    fi

    sleep 0.15
    if ! is_on; then
        echo "Error: Could not start the sleep inhibitor" >&2
        return 1
    fi
    state_set caffeine_enabled on
    notify "caffeine" "The screen will stay on and unlocked" \
        preferences-desktop-screensaver low
    refresh
}

function caffeine_off() {
    local pid
    if is_on; then
        pid=$(cat "$PIDFILE" 2>/dev/null)
        # setsid creates a separate process group; also stop its child sleep.
        if [ "$(ps -o pgid= -p "$pid" | tr -d ' ')" = "$pid" ]; then
            kill -- "-$pid" 2>/dev/null
        else
            kill "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi

    if [ -n "${DISPLAY:-}" ] && command -v xset >/dev/null 2>&1; then
        # Restore X defaults: a ten-minute screensaver and the usual DPMS timeouts.
        xset s on +dpms 2>/dev/null
        xset s 600 600 2>/dev/null
        xset dpms 600 900 1200 2>/dev/null
    fi

    state_set caffeine_enabled off
    notify "caffeine" "Automatic locking enabled" \
        preferences-desktop-screensaver low
    refresh
}

function refresh() {
    command -v eww >/dev/null 2>&1 || return 0
    eww -c "$HOME/.config/eww" update \
        caffeine="$(is_on && printf 'on' || printf 'off')" 2>/dev/null || true
}

function main() {
    local action="toggle"

    while (($#)); do
        case $1 in
        -t | --toggle) action="toggle" ;;
        -o | --on) action="on" ;;
        -f | --off) action="off" ;;
        --restore) action="restore" ;;
        -s | --status) action="status" ;;
        -i | --icon) action="icon" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    restore)
        case "$(state_get caffeine_enabled '')" in
        on) caffeine_on ;;
        off) caffeine_off ;;
        *) is_on && state_set caffeine_enabled on || state_set caffeine_enabled off ;;
        esac
        ;;
    toggle) if is_on; then caffeine_off; else caffeine_on; fi ;;
    on) caffeine_on ;;
    off) caffeine_off ;;
    status) is_on && printf 'on' || printf 'off' ;;
    icon) is_on && printf '󰅶' || printf '󰛊' ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
