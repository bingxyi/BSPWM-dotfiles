#!/usr/bin/env bash
# offsec-dotfiles :: biblioteca comum dos scripts
# Uso: . "$HOME/.config/offsec/bin/lib.sh"

OFFSEC_DIR="$HOME/.config/offsec"
THEME_FILE="$OFFSEC_DIR/current-theme.conf"
THEMES_DIR="$OFFSEC_DIR/themes"
TEMPLATES_DIR="$OFFSEC_DIR/templates"
WALLPAPER_DIR="${OFFSEC_WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/offsec"
ROFI_THEME="$HOME/.config/rofi/themes/offsec.rasi"
ROFI_MENU_THEME="$HOME/.config/rofi/themes/menu.rasi"
ROFI_GRID_THEME="$HOME/.config/rofi/themes/grid.rasi"

mkdir -p "$STATE_DIR"

function theme_get() {
    local key="$1" fallback="${2:-}" name value=""
    if [ -r "$THEME_FILE" ]; then
        while IFS='=' read -r name value || [[ -n "$name" ]]; do
            if [[ "$name" == "$key" ]]; then
                printf '%s' "${value:-$fallback}"
                return 0
            fi
        done < "$THEME_FILE"
    fi
    printf '%s' "$fallback"
}

function state_get() {
    local key="$1" fallback="${2:-}"
    if [ -r "$STATE_DIR/$key" ]; then
        printf '%s' "$(<"$STATE_DIR/$key")"
        return 0
    fi
    printf '%s' "$fallback"
}

function state_set() {
    local key="$1" value="$2"
    local tmp
    tmp=$(mktemp "$STATE_DIR/.${key}.XXXXXX") || return 1
    if printf '%s' "$value" >"$tmp" && mv -f -- "$tmp" "$STATE_DIR/$key"; then
        return 0
    fi
    rm -f -- "$tmp"
    return 1
}

function state_clear() {
    rm -f "$STATE_DIR/$1"
}

function notify() {
    local title="$1" body="${2:-}" icon="${3:-dialog-information}" urgency="${4:-normal}"
    command -v notify-send &>/dev/null || return 0
    notify-send -a archlinux -u "$urgency" -i "$icon" \
        -h "string:x-dunst-stack-tag:offsec-$title" "$title" "$body"
}

function rofi_menu() {
    local prompt="$1" theme="${2:-$ROFI_MENU_THEME}"
    shift 2 2>/dev/null || shift
    rofi -dmenu -i -p "$prompt" -theme "$theme" "$@"
}

function rofi_input() {
    local prompt="$1" placeholder="${2:-}"
    printf '' | rofi -dmenu -i -p "$prompt" -theme "$ROFI_MENU_THEME" \
        -theme-str "entry { placeholder: \"$placeholder\"; }" -lines 0
}

function rofi_confirm() {
    local question="$1" answer=""
    answer=$(printf 'No\nYes' | rofi -dmenu -i -p "$question" \
        -theme "$ROFI_MENU_THEME" -lines 2)
    [ "$answer" = "Yes" ]
}

function exit_on_missing_tools() {
    local cmd
    for cmd in "$@"; do
        if command -v "$cmd" &>/dev/null; then
            continue
        fi
        printf "Error: tool '%s' not found in PATH\n" "$cmd" >&2
        notify "archlinux" "Missing dependency: $cmd" dialog-error critical
        exit 1
    done
}

function active_profile() {
    if [ -r "$OFFSEC_DIR/profile" ]; then
        local profile
        IFS= read -r profile < "$OFFSEC_DIR/profile" || :
        printf '%s' "${profile:-nyx}"
        return 0
    fi
    printf 'nyx'
}
