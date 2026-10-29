#!/usr/bin/env bash
case "${1:---toggle}" in
--open) exec "$HOME/.config/offsec/bin/panel.sh" open media;;
--close) exec "$HOME/.config/offsec/bin/panel.sh" close media;;
--toggle) exec "$HOME/.config/offsec/bin/panel.sh" toggle media;;
--status) exec "$HOME/.config/offsec/bin/panel.sh" status media;;
--glyph) printf '󰝚\n';;
cycle) exec /usr/bin/python "$HOME/.config/offsec/bin/media-state.py" cycle;;
play-pause|next|previous|seek)
    runtime="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/offsec/media}"
    instance=$(jq -r '.instance // empty' "$runtime/offsec-media.json" 2>/dev/null)
    [[ -n "$instance" ]] || exit 0
    if [[ "$1" != seek ]]; then
        exec playerctl --player "$instance" "$1"
    fi
    percent="${2:-}"
    [[ "$percent" =~ ^[0-9]+([.][0-9]+)?$ ]] || exit 2
    length=$(playerctl --player "$instance" metadata --format '{{mpris:length}}' 2>/dev/null)
    [[ "$length" =~ ^[0-9]+$ && "$length" -gt 0 ]] || exit 0
    seconds=$(awk -v p="$percent" -v us="$length" 'BEGIN {if(p>100)p=100; printf "%.6f", us*p/100000000}')
    exec playerctl --player "$instance" position "$seconds"
    ;;
*) exit 2;;
esac
