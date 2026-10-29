#!/usr/bin/env bash
# BSPWM-dotfiles :: manage engagements (structure, notes, session context)
# The active engagement feeds the bar, shell prompt, and screenshot.sh.

SCRIPT_NAME=${0##*/}
VERSION="1.0.0"

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

ENGAGEMENT_ROOT="${ENGAGEMENT_DIR:-$HOME/engagements}"
SUBDIRS=(recon scans evidence loot exploits notes reports tools)

function usage() {
    cat <<EOM

Manage the active engagement.
usage: ${SCRIPT_NAME} [options]
    --menu            Open the engagement menu
    --new             Create an engagement (asks for a name)
    --switch          Select an engagement
    --terminal        Open a terminal here
    --note            Add a quick journal note
    --evidence        Print the evidence directory
    --current         Print the active engagement path
    --name            Print the active name
    --close           Close the current context
    --help            Show this help
    --version         Show version

EOM
    exit 1
}

function main() {
    local action="menu"

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -n | --new) action="new" ;;
        -w | --switch) action="switch" ;;
        -t | --terminal) action="terminal" ;;
        --note) action="note" ;;
        --evidence) action="evidence" ;;
        --current) action="current" ;;
        --name) action="name" ;;
        --close) action="close" ;;
        --version)
            echo "${SCRIPT_NAME} ${VERSION}"
            exit 0
            ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    mkdir -p "$ENGAGEMENT_ROOT"

    case "$action" in
    menu) menu_engagement ;;
    new) new_engagement ;;
    switch) switch_engagement ;;
    terminal) open_terminal ;;
    note) quick_note ;;
    evidence) evidence_dir ;;
    current) state_get engagement "" && echo ;;
    name) print_name ;;
    close) close_engagement ;;
    esac
}

function menu_engagement() {
    local choice
    choice=$(printf '󰎔  New engagement\n󰋊  Switch engagement\n  Open terminal here\n󰏫  Quick note\n󰉋  Open in file manager\n󰅖  Close active engagement\n' |
        rofi -dmenu -i -p "engagement" -theme "$ROFI_MENU_THEME" -lines 6)
    case "$choice" in
    *New*) new_engagement ;;
    *Switch*) switch_engagement ;;
    *terminal*) open_terminal ;;
    *note*) quick_note ;;
    *manager*) open_files ;;
    *Close*) close_engagement ;;
    esac
}

function new_engagement() {
    local name slug path
    name=$(rofi_input "Engagement name" "e.g.: acme-webapp")
    [ -z "$name" ] && exit 0

    slug=$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')
    if [ -z "$slug" ]; then
        notify "engagement" "Invalid name" dialog-error critical
        exit 1
    fi

    path="$ENGAGEMENT_ROOT/$(date +%Y-%m)-$slug"
    if ! mkdir -p "$path"; then
        echo "Error: could not create $path" >&2
        exit 1
    fi

    local dir
    for dir in "${SUBDIRS[@]}"; do
        mkdir -p "$path/$dir"
    done

    write_readme "$path" "$name"
    printf '# journal — %s\n\n' "$name" >"$path/notes/journal.md"
    printf 'target=\nscope=\nproxy=127.0.0.1:8080\n' >"$path/.offsec"

    state_set engagement "$path"
    refresh_bar
    notify "Engagement created" "$path" folder
    open_terminal
}

function write_readme() {
    local path="$1" name="$2"
    cat >"$path/README.md" <<EOM
# ${name}

- Started: $(date '+%Y-%m-%d')
- Scope: _fill in_
- Test credentials: _fill in_
- Testing window: _fill in_

## Structure

| Directory | Purpose |
|---|---|
| recon | Passive enumeration, subdomains and generated wordlists |
| scans | Output from nmap, nuclei, ffuf and ZAP |
| evidence | Screenshots and captures |
| loot | Credentials, tokens and dumps |
| exploits | Saved proofs of concept and requests |
| notes | Journal and endpoint notes |
| reports | Draft and final report |
| tools | Temporary scripts for this engagement |

## Findings

| ID | Severity | Title | Status |
|---|---|---|---|
EOM
}

function switch_engagement() {
    local chosen
    chosen=$(find "$ENGAGEMENT_ROOT" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null |
        sort -r | rofi -dmenu -i -p "open" -theme "$ROFI_MENU_THEME")
    [ -z "$chosen" ] && exit 0

    state_set engagement "$ENGAGEMENT_ROOT/$chosen"
    load_target "$ENGAGEMENT_ROOT/$chosen"
    refresh_bar
    notify "Active engagement" "$chosen" folder-open
}

function load_target() {
    local path="$1" target=""
    if [ -r "$path/.offsec" ]; then
        target=$(awk -F= '/^target=/ {print $2; exit}' "$path/.offsec")
    fi
    if [ -n "$target" ]; then
        state_set target "$target"
    fi
}

function current_path() {
    local path
    path=$(state_get engagement "")
    if [ -z "$path" ] || [ ! -d "$path" ]; then
        printf '%s' "$HOME"
        return 1
    fi
    printf '%s' "$path"
}

function print_name() {
    local path
    path=$(state_get engagement "")
    if [ -z "$path" ]; then
        printf 'No engagement'
        return 0
    fi
    basename "$path"
}

function open_terminal() {
    local path
    path=$(current_path)
    kitty --directory "$path" &
    disown
    return 0
}

function open_files() {
    local path
    path=$(current_path)
    if command -v thunar &>/dev/null; then
        thunar "$path" &
        disown
        return 0
    fi
    kitty --directory "$path" -e yazi &
    disown
}

function quick_note() {
    local path note journal
    path=$(current_path)
    if [ "$path" = "$HOME" ]; then
        notify "engagement" "No active engagement" dialog-warning critical
        exit 1
    fi

    note=$(rofi_input "note" "What just happened?")
    [ -z "$note" ] && exit 0

    journal="$path/notes/journal.md"
    mkdir -p "$(dirname "$journal")"
    printf -- '- **%s** %s\n' "$(date '+%d/%m %H:%M')" "$note" >>"$journal"
    notify "Note saved" "$(basename "$path")/notes/journal.md" accessories-text-editor low
}

function evidence_dir() {
    local path
    path=$(state_get engagement "")
    if [ -n "$path" ] && [ -d "$path/evidence" ]; then
        printf '%s' "$path/evidence"
        return 0
    fi
    printf '%s' "$HOME/Pictures/screenshots"
}

function close_engagement() {
    state_clear engagement
    state_clear target
    refresh_bar
    notify "engagement" "Context closed" folder low
}

function refresh_bar() {
    if command -v eww &>/dev/null; then
        eww -c "$HOME/.config/eww" update engagement="$(print_name)" 2>/dev/null
    fi
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
