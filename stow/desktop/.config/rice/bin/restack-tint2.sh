#!/usr/bin/env bash
# Keep tint2 below applications, but above bspwm's invisible input windows.
set -euo pipefail

mapfile -t bars < <(xdotool search --onlyvisible --class '^Tint2$' 2>/dev/null || true)
((${#bars[@]})) || exit 0

for window in "${bars[@]}"; do
    xdotool windowlower "$window"
done

# Absolute lowering puts the dock behind the monitor's InputOnly window:
# it remains visible, but that window intercepts every mouse event.
while read -r window; do
    if xprop -id "$window" WM_CLASS 2>/dev/null | grep -Fq '"root", "Bspwm"'; then
        xdotool windowlower "$window"
    fi
done < <(xdotool search --onlyvisible --classname '^root$' 2>/dev/null || true)
