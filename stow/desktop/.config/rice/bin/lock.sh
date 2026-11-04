#!/usr/bin/env bash
# rice :: lock immediately using the prepared theme image, without RandR changes.
# wallpaper.sh prepares dimblur asynchronously when the wallpaper changes.
# Never re-render images, disable outputs or expose an intermediate desktop here.

. "$HOME/.config/rice/bin/lib.sh"

usage() {
    printf '%s\n' 'usage: lock.sh [--keep-monitors|--help]' \
        'All connected monitors remain active; --keep-monitors is a compatibility alias.'
}

main() {
    while (($#)); do
        case "$1" in
        -k|--keep-monitors) ;; # compatibility with existing bindings/callers
        -h|--help) usage; return 0;;
        *) usage >&2; return 2;;
        esac
        shift
    done
    # Repeated clicks must not start competing lockers. Keep fd open until unlock.
    exec 9>"${XDG_RUNTIME_DIR:-$STATE_DIR}/rice-screen-lock.lock"
    flock -n 9 || return 0
    # Remove any in-flight visual snapshot before the secure locker maps.
    if [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rice-motion.sock" ]; then
        "$RICE_DIR/bin/motion.py" --cancel || true
    fi
    do_lock
}

do_lock() {
    if command -v betterlockscreen >/dev/null 2>&1; then
        if betterlockscreen --lock dimblur --off 300; then return 0; fi
        printf '%s\n' 'betterlockscreen failed; trying the solid-color locker' >&2
    fi
    if command -v i3lock >/dev/null 2>&1; then
        local color
        color=$(theme_get bg '#1e1e2e')
        i3lock -c "${color#\#}" --nofork
        return $?
    fi
    printf '%s\n' 'Error: no working screen locker (betterlockscreen or i3lock)' >&2
    notify 'Lock failed' 'No working screen locker is available' dialog-error critical
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; exit $?; fi
