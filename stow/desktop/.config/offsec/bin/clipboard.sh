#!/usr/bin/env bash
# Purpose: clipboard history through greenclip and rofi
# Usage: clipboard.sh

THEME="$HOME/.config/rofi/themes/menu.rasi"

if ! command -v greenclip &>/dev/null; then
    notify-send -a archlinux -u critical "clipboard" "greenclip not installed (AUR: rofi-greenclip)"
    exit 1
fi

if ! pgrep -f "greenclip daemon" >/dev/null 2>&1; then
    (greenclip daemon >/dev/null 2>&1 &)
    sleep 1
fi

selection=$(greenclip print | grep -v '^\s*$' | rofi -dmenu -i -p "clipboard" \
    -theme "$THEME" -theme-str 'window {width: 45%;} listview {lines: 12;}')

if [ -n "$selection" ]; then
    printf '%s' "$selection" | greenclip print >/dev/null 2>&1
    printf '%s' "$selection" | xclip -selection clipboard
fi
exit 0
