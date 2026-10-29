#!/usr/bin/env bash
# BSPWM-dotfiles :: synchronize Eww variables with the current state
# Called when the Vesper bar starts and optionally in a loop.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

EWW_CONFIG="$HOME/.config/eww"

function usage() {
    cat <<EOM

Update desktop panel status.
usage: ${SCRIPT_NAME} [--once|--watch [seconds]|--help]
    --once      Update once (default)
    --watch     Update continuously (default: 10 seconds)

EOM
    exit 1
}

function main() {
    local action="once" interval=10

    while (($#)); do
        case $1 in
        -o | --once) action="once" ;;
        -w | --watch)
            action="watch"
            if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
                interval="$2"
                shift
            fi
            ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    if ! command -v eww &>/dev/null; then
        exit 0
    fi

    case "$action" in
    once) push ;;
    watch)
        while true; do
            push
            sleep "$interval"
        done
        ;;
    esac
}

function push() {
    eww -c "$EWW_CONFIG" update \
        volume="$("$OFFSEC_DIR/bin/volume.sh" --get 2>/dev/null || echo 0)" \
        target="$(state_get target 'No target')" \
        vpn="$("$OFFSEC_DIR/bin/vpn.sh" --status 2>/dev/null || echo off)" \
        engagement="$("$OFFSEC_DIR/bin/engagement.sh" --name 2>/dev/null)" \
        notif_count="$("$OFFSEC_DIR/bin/notifications.sh" --count 2>/dev/null || echo 0)" \
        2>/dev/null
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
