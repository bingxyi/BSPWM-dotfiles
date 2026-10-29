#!/usr/bin/env bash
# Purpose: seletor de glifos/emoji para relatórios e notas; copia para o clipboard
# Usage: emoji.sh

GLYPHS="$HOME/.config/offsec/glyphs.txt"
THEME="$HOME/.config/rofi/themes/menu.rasi"

if [ ! -r "$GLYPHS" ]; then
    echo "Error: $GLYPHS not found" >&2
    exit 1
fi

selection=$(grep -v '^#' "$GLYPHS" | grep -v '^\s*$' |
    rofi -dmenu -i -p "glyph" -theme "$THEME" \
        -theme-str 'window {width: 40%;} listview {lines: 12;}')

[ -z "$selection" ] && exit 0

printf '%s' "${selection%% *}" | xclip -selection clipboard
notify-send -a archlinux -u low "Glyph copied" "$selection"
exit 0
