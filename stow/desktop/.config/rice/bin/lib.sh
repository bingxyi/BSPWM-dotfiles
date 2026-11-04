# Recover the existing per-user runtime on minimal X11 launch environments.
if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    rice_runtime="/run/user/$(id -u)"
    if [ -d "$rice_runtime" ] && [ -O "$rice_runtime" ]; then
        export XDG_RUNTIME_DIR="$rice_runtime"
    fi
    unset rice_runtime
fi

#!/usr/bin/env bash
# rice :: shared script library
# Usage: . "$HOME/.config/rice/bin/lib.sh"

RICE_DIR="$HOME/.config/rice"
THEME_FILE="$RICE_DIR/current-theme.conf"
THEMES_DIR="$RICE_DIR/themes"
TEMPLATES_DIR="$RICE_DIR/templates"
WALLPAPER_DIR="${RICE_WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rice"
ROFI_THEME="$HOME/.config/rofi/themes/rice.rasi"
ROFI_MENU_THEME="$HOME/.config/rofi/themes/menu.rasi"
ROFI_GRID_THEME="$HOME/.config/rofi/themes/grid.rasi"


# libdbus clients such as dunstctl need an explicit user bus on minimal X11 sessions.
# Reuse the existing systemd user bus; never create a second isolated session bus.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    rice_user_bus="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus"
    if [ -S "$rice_user_bus" ]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$rice_user_bus"
    fi
    unset rice_user_bus
fi

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
        -h "string:x-dunst-stack-tag:rice-$title" "$title" "$body"
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
    if [ -r "$RICE_DIR/profile" ]; then
        local profile
        IFS= read -r profile < "$RICE_DIR/profile" || :
        printf '%s' "${profile:-nyx}"
        return 0
    fi
    printf 'nyx'
}
