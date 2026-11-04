#!/usr/bin/env bash
# rice :: reliable, serialized keep-awake state with reversible X11 settings.
. "$HOME/.config/rice/bin/lib.sh"
PIDFILE="$STATE_DIR/caffeine.pid"
XSET_SAVED="$STATE_DIR/caffeine-xset"

function is_on() {
    local pid
    [[ -r "$PIDFILE" ]] && read -r pid < "$PIDFILE" || return 1
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null && grep -qaF 'Caffeine mode active' "/proc/$pid/cmdline" 2>/dev/null
}

function save_xset() {
    [[ -n "${DISPLAY:-}" ]] && command -v xset >/dev/null || return 0
    LC_ALL=C xset q | awk '
        /timeout:/ {timeout=$2;cycle=$4}
        /Standby:/ {standby=$2;suspend=$4;off=$6}
        /DPMS is Enabled/ {enabled=1}
        END {if (timeout!="") print timeout,cycle,standby+0,suspend+0,off+0,enabled+0}
    ' > "$XSET_SAVED"
}

function restore_xset() {
    [[ -n "${DISPLAY:-}" ]] && command -v xset >/dev/null || return 0
    [[ -s "$XSET_SAVED" ]] || return 0
    local timeout=600 cycle=600 standby=600 suspend=900 off=1200 enabled=1 value
    if [[ -s "$XSET_SAVED" ]]; then
        read -r timeout cycle standby suspend off enabled < "$XSET_SAVED"
        for value in "$timeout" "$cycle" "$standby" "$suspend" "$off" "$enabled"; do
            [[ "$value" =~ ^[0-9]+$ ]] || { echo 'Invalid saved display settings' >&2; return 1; }
        done
    fi
    xset s "$timeout" "$cycle" || return 1
    if [[ "$enabled" == 1 ]]; then
        xset +dpms && xset dpms "$standby" "$suspend" "$off"
    else
        xset -dpms
    fi
}

function refresh() {
    command -v eww >/dev/null || return 0
    eww -c "$HOME/.config/eww" update caffeine="$(is_on && printf on || printf off)" 2>/dev/null || true
}

function caffeine_on() {
    if is_on; then
        [[ -z "${DISPLAY:-}" ]] || xset s off -dpms || return 1
        state_set caffeine_enabled on; refresh; return 0
    fi
    command -v systemd-inhibit >/dev/null || { echo 'systemd-inhibit is unavailable' >&2; return 1; }
    save_xset || return 1
    [[ -z "${DISPLAY:-}" ]] || xset s off -dpms || return 1
    # Close the action lock in the long-lived child so the next click can proceed.
    setsid systemd-inhibit --what=idle:sleep --who=archlinux \
        --why='Caffeine mode active' --mode=block sleep infinity \
        >/dev/null 2>&1 8>&- &
    printf '%s\n' "$!" > "$PIDFILE"
    local attempt
    for ((attempt=0;attempt<30;attempt++)); do
        is_on && break
        sleep .02
    done
    if ! is_on; then
        rm -f "$PIDFILE"; restore_xset
        echo 'Could not start the sleep inhibitor' >&2; return 1
    fi
    state_set caffeine_enabled on; refresh
    (notify caffeine 'The screen will stay on and unlocked' preferences-desktop-screensaver low 8>&-) >/dev/null 2>&1 &
}

function caffeine_off() {
    local pid
    if is_on; then
        read -r pid < "$PIDFILE"
        if [[ "$(ps -o pgid= -p "$pid" | tr -d ' ')" == "$pid" ]]; then
            kill -- "-$pid" 2>/dev/null || true
        else
            kill "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$PIDFILE"
    restore_xset || return 1
    state_set caffeine_enabled off; refresh
    (notify caffeine 'Automatic locking restored' preferences-desktop-screensaver low 8>&-) >/dev/null 2>&1 &
}

function main() {
    local action="${1:---toggle}"
    case "$action" in
        --status|-s) is_on && printf on || printf off; return 0;;
        --icon|-i) is_on && printf '󰅶' || printf '󰛊'; return 0;;
        --help|-h) printf 'usage: caffeine.sh --toggle|--on|--off|--status|--restore\n'; return 0;;
        --toggle|-t|--on|-o|--off|-f|--restore) ;;
        *) echo 'Invalid caffeine action' >&2; return 2;;
    esac
    exec 8>"$STATE_DIR/caffeine.lock"
    flock -w 4 8 || return 1
    case "$action" in
        --on|-o) caffeine_on;;
        --off|-f) caffeine_off;;
        --toggle|-t) if is_on; then caffeine_off; else caffeine_on; fi;;
        --restore)
            case "$(state_get caffeine_enabled '')" in
                on) caffeine_on;;
                off) caffeine_off;;
                *) refresh;;
            esac;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
