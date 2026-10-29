#!/usr/bin/env bash
# BSPWM-dotfiles :: lock the session using the active theme
#
# Turn off secondary monitors through xrandr while locked.
# The greeter draws only on the primary output; the portrait monitor stays
# black instead of displaying a stretched lock screen.
#
# Restore monitors through EXIT/INT/TERM/HUP traps if the locker exits,
# is killed, or the session ends. Always restore disabled outputs.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

MONITORS_SH="$HOME/.config/bspwm/monitors.sh"

function usage() {
    cat <<EOM

Lock the session with the current theme.
usage: ${SCRIPT_NAME} [--keep-monitors|--help]
    --keep-monitors   Keep secondary monitors enabled

EOM
    exit 1
}

function primary_monitor() {
    xrandr --query 2>/dev/null | awk '/ connected primary/ {print $1; exit}'
}

function secondary_monitors() {
    local primary
    primary=$(primary_monitor)
    # Without a primary output, secondary outputs cannot be identified; leave them alone.
    [ -z "$primary" ] && return 0
    xrandr --query 2>/dev/null | awk '/ connected/ {print $1}' | grep -vxF "$primary"
}

function monitors_off() {
    local m count=0
    while read -r m; do
        [ -z "$m" ] && continue
        xrandr --output "$m" --off 2>/dev/null && count=$((count + 1))
    done < <(secondary_monitors)
    [ "$count" -gt 0 ] && state_set lock_monitors_off 1
    return 0
}

# monitors.sh owns the geometry, as in bspwmrc.
# Restore it by rerunning that script rather than duplicating positions here.
function monitors_restore() {
    [ "$(state_get lock_monitors_off 0)" = "1" ] || return 0
    if [ -x "$MONITORS_SH" ]; then
        "$MONITORS_SH" >/dev/null 2>&1
    elif [ -r "$MONITORS_SH" ]; then
        bash "$MONITORS_SH" >/dev/null 2>&1
    else
        local m
        while read -r m; do
            [ -n "$m" ] && xrandr --output "$m" --auto 2>/dev/null
        done < <(xrandr --query | awk '/ connected/ {print $1}')
    fi
    # RandR restores pixels; bspwm also needs its retained padding and order reset.
    if command -v bspc >/dev/null 2>&1; then
        "$OFFSEC_DIR/bin/monitor-sync.py" || return 1
    fi
    state_clear lock_monitors_off
    return 0
}

function do_lock() {
    if command -v betterlockscreen >/dev/null 2>&1; then
        local wallpaper
        wallpaper=$(state_get wallpaper '')
        # Render after monitors_off, using the current wallpaper and lock geometry.
        # A cache built on the desktop has a different size with the portrait screen.
        if [ -r "$wallpaper" ]; then
            betterlockscreen --update "$wallpaper" --fx dimblur >/dev/null 2>&1
        fi
        betterlockscreen --lock dimblur --off 300
        return $?
    fi

    if command -v i3lock >/dev/null 2>&1; then
        local color
        color=$(theme_get bg '#1e1e2e')
        i3lock -c "${color#\#}" --nofork
        return $?
    fi

    echo "Error: no screen locker found (betterlockscreen or i3lock)" >&2
    notify "lock" "betterlockscreen not installed" dialog-error critical
    return 1
}

function main() {
    local keep=0

    while (($#)); do
        case $1 in
        -k | --keep-monitors) keep=1 ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    if [ "$keep" -eq 0 ]; then
        trap monitors_restore EXIT INT TERM HUP
        monitors_off
    fi

    do_lock
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
