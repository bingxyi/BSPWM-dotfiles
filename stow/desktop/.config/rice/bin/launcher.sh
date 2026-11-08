#!/usr/bin/env bash
# Purpose: application launcher (rofi drun) using the active theme
# Usage: launcher.sh

# Launch applications with the existing user audio runtime and session bus.
# bspwm may still carry the environment from before the session was repaired.
if [ -r "$HOME/.config/rice/env" ]; then
    . "$HOME/.config/rice/env"
fi

ROFI_THEME="$HOME/.config/rofi/themes/rice.rasi"

if ! command -v rofi &>/dev/null; then
    echo "Error: rofi is not installed" >&2
    exit 1
fi

if pgrep -x rofi >/dev/null 2>&1; then
    pkill -x rofi
    exit 0
fi

exec rofi -show drun -show-icons -theme "$ROFI_THEME"
