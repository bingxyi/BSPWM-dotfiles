#!/usr/bin/env bash
# Purpose: application launcher (rofi drun) using the active theme
# Usage: launcher.sh

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
