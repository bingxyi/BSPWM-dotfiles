#!/usr/bin/env bash
# Purpose: read sxhkdrc and show shortcut comments and keys in rofi
# Usage: cheatsheet.sh

SXHKDRC="$HOME/.config/sxhkd/sxhkdrc"
THEME="$HOME/.config/rofi/themes/menu.rasi"

if [ ! -r "$SXHKDRC" ]; then
    echo "Error: $SXHKDRC not found" >&2
    exit 1
fi

awk '
    /^#[^#]/ { desc = substr($0, 2); gsub(/^ +/, "", desc); next }
    /^[^#[:space:]]/ {
        if (desc != "") { printf "%-34s  %s\n", $0, desc; desc = "" }
        next
    }
' "$SXHKDRC" | rofi -dmenu -i -p "shortcuts" -theme "$THEME" \
    -theme-str 'window {width: 55%;} listview {lines: 16;} element-text {font: "JetBrainsMono Nerd Font 11";}' \
    >/dev/null
exit 0
