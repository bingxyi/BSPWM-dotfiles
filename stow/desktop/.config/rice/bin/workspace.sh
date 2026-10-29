#!/usr/bin/env bash
# rice :: focus/send workspaces with any monitors.sh layout
# Use numeric desktop names when available; otherwise use the desktop index
# on the focused monitor. Never write to monitors.sh.

SCRIPT_NAME=${0##*/}

function usage() {
    cat <<EOM

Focus a workspace or send a window.
usage: ${SCRIPT_NAME} [--focus|--send] <number>

EOM
    exit 1
}

function main() {
    local action="" index=""

    while (($#)); do
        case $1 in
        -f | --focus)
            shift
            index="$1"
            action="focus"
            ;;
        -s | --send)
            shift
            index="$1"
            action="send"
            ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    if [ -z "$action" ] || [ -z "$index" ]; then
        echo "Error: provide the action and workspace number" >&2
        usage
    fi

    local target
    target=$(resolve_desktop "$index")
    if [ -z "$target" ]; then
        exit 0
    fi

    case "$action" in
    focus) bspc desktop -f "$target" ;;
    send) bspc node -d "$target" --follow ;;
    esac
}

function resolve_desktop() {
    local index="$1" name
    [[ "$index" =~ ^[1-9][0-9]*$ ]] || return 1
    local -a all local_desktops
    mapfile -t all < <(bspc query -D --names)
    for name in "${all[@]}"; do
        if [[ "$name" == "$index" ]]; then
            printf '%s' "$name"
            return 0
        fi
    done
    mapfile -t local_desktops < <(bspc query -D -m focused --names)
    if (( index <= ${#local_desktops[@]} )); then
        printf '%s' "${local_desktops[index-1]}"
    elif (( index <= ${#all[@]} )); then
        printf '%s' "${all[index-1]}"
    else
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
