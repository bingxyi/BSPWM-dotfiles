#!/usr/bin/env bash
# BSPWM-dotfiles :: start the active profile sidebar
#   nyx    -> tint2 (lightweight native X11 vertical panel)
#   vesper -> eww   (GTK widgets with expandable panels)
# Fall back to the other backend if the selected one is unavailable.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

EWW_CONFIG="$HOME/.config/eww"

function usage() {
    cat <<EOM

Start the desktop bar.
usage: ${SCRIPT_NAME} [--restart|--start|--stop|--help]
    --restart   Restart the bar (default)
    --start     Start if not running

EOM
    exit 1
}

function main() {
    local action="restart"

    # theme.sh calls "bar.sh --restart &" in the background. Rapid theme changes
    # can overlap: both restarts kill tint2, wait, and launch another instance,
    # leaving stacked bars with twice the reserved strut.
    # Serialize restarts so the second waits for the first to finish.
    exec 9>"${XDG_RUNTIME_DIR:-$STATE_DIR}/offsec-bar.lock"
    flock 9 || return 1

    while (($#)); do
        case $1 in
        -r | --restart) action="restart" ;;
        -s | --start) action="start" ;;
        -k | --stop) action="stop" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    stop) stop_bars ;;
    start)
        pgrep -u "$UID" -x tint2 >/dev/null && return 0
        if command -v eww >/dev/null; then
            eww -c "$EWW_CONFIG" active-windows 2>/dev/null | grep -q '^bar:' && return 0
        fi
        start_bar
        ;;
    restart)
        stop_bars
        sleep 0.4
        start_bar
        ;;
    esac
}

function stop_bars() {
    # Release the temporary Escape grab and any transparent input windows.
    "$OFFSEC_DIR/bin/panel.sh" close-all >/dev/null 2>&1
    pkill -u "$UID" -x tint2 2>/dev/null
    pkill -f "eww-poll.sh --watch" 2>/dev/null
    # Keep Eww warm; panel.sh closed windows under the shared popup lock.
    return 0
}

function start_bar() {
    if [ "$(active_profile)" = "vesper" ]; then
        start_eww || start_tint2
    else
        start_tint2 || start_eww
    fi
}

function start_tint2() {
    if ! command -v tint2 &>/dev/null; then
        notify "bar" "tint2 not installed" dialog-error critical
        return 1
    fi
    if [ ! -r "$HOME/.config/tint2/tint2rc" ]; then
        "$OFFSEC_DIR/bin/theme.sh" --render-only --apply "$(theme_get name catppuccin-mocha)" 9>&- || return 1
    fi

    # 9>&- prevents tint2 from inheriting the lock and blocking future restarts.
    setsid -f tint2 -c "$HOME/.config/tint2/tint2rc" >"$STATE_DIR/tint2.log" 2>&1 9>&-
    sleep 1
    if pgrep -x tint2 >/dev/null 2>&1; then
        "$OFFSEC_DIR/bin/restack-tint2.sh" || return 1
        return 0
    fi
    notify "bar" "tint2 failed to start (see $STATE_DIR/tint2.log)" dialog-error critical
    return 1
}

function start_eww() {
    if ! command -v eww &>/dev/null; then
        notify "bar" "eww not installed (AUR: eww-git)" dialog-error critical
        return 1
    fi

    local screen
    screen=$(xrandr --listmonitors 2>/dev/null | awk '/\*/ {gsub(":", "", $1); print $1; exit}')
    [ -z "$screen" ] && screen=0

    # The daemon must also close the lock because it outlives its launcher.
    eww -c "$EWW_CONFIG" daemon >"$STATE_DIR/eww.log" 2>&1 9>&- || return 1
    local attempt
    for ((attempt=0; attempt<60; attempt++)); do
        eww -c "$EWW_CONFIG" ping >/dev/null 2>&1 && break
        sleep 0.05
    done
    eww -c "$EWW_CONFIG" ping >/dev/null 2>&1 || return 1
    if eww -c "$EWW_CONFIG" open bar --screen "$screen" >>"$STATE_DIR/eww.log" 2>&1; then
        "$OFFSEC_DIR/bin/eww-poll.sh" --once
        pkill -f "eww-poll.sh --watch" 2>/dev/null
        ("$OFFSEC_DIR/bin/eww-poll.sh" --watch 15 9>&- &) >/dev/null 2>&1
        return 0
    fi

    notify "bar" "eww failed (see $STATE_DIR/eww.log)" dialog-error critical
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
