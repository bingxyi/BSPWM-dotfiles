#!/usr/bin/env bash
# Machine overrides: ~/.config/bspwm/monitors.local.sh (never versioned).
# MON_H/MON_V, MODE_H/MODE_V, RATE_H/RATE_V, ROTATE_V, VERTICAL_SIDE.
[[ ! -r "$HOME/.config/bspwm/monitors.local.sh" ]] || . "$HOME/.config/bspwm/monitors.local.sh"
layout=$(xrandr --query) || exit 1
mapfile -t outputs < <(awk '/ connected/ {print $1}' <<< "$layout")
((${#outputs[@]})) || { printf 'monitors: no connected output\n' >&2; exit 1; }
connected() { local out; for out in "${outputs[@]}"; do [[ "$out" == "$1" ]] && return 0; done; return 1; }
MON_H=${MON_H:-HDMI-0}
MON_V=${MON_V:-DVI-D-0}
connected "$MON_H" || MON_H=${outputs[0]}
if ! connected "$MON_V" || [[ "$MON_H" == "$MON_V" ]]; then
    MON_V=''
    for output in "${outputs[@]}"; do
        [[ "$output" == "$MON_H" ]] || { MON_V=$output; break; }
    done
fi
ROTATE_V=${ROTATE_V:-right}
VERTICAL_SIDE=${VERTICAL_SIDE:-left}
case "$ROTATE_V" in normal|left|right|inverted) ;; *) exit 2;; esac
case "$VERTICAL_SIDE" in left|right) ;; *) exit 2;; esac
# Read unrotated preferred modes once; use them to retain vertical centering.
native_mode() {
    awk -v output="$1" '
        /^[^[:space:]]/ { active=($1==output && $2=="connected") }
        active && /^[[:space:]]+[0-9]+x[0-9]+/ {
            if (!first) first=$1
            if (index($0,"+")) {print $1; found=1; exit}
        }
        END {if (!found) print first}
    ' <<< "$layout"
}
MODE_H=${MODE_H:-$(native_mode "$MON_H")}
MODE_V=${MODE_V:-$(native_mode "$MON_V")}
pos_h=0x0
pos_v=0x0
if [[ "$MODE_H" =~ ^[0-9]+x[0-9]+$ && "$MODE_V" =~ ^[0-9]+x[0-9]+$ ]]; then
    h_width=${MODE_H%x*}; h_height=${MODE_H#*x}
    v_width=${MODE_V%x*}; v_height=${MODE_V#*x}
    if [[ "$ROTATE_V" == left || "$ROTATE_V" == right ]]; then
        v_width=${MODE_V#*x}; v_height=${MODE_V%x*}
    fi
    h_y=$((v_height > h_height ? (v_height-h_height)/2 : 0))
    v_y=$((h_height > v_height ? (h_height-v_height)/2 : 0))
    if [[ "$VERTICAL_SIDE" == left ]]; then
        pos_h="${v_width}x${h_y}"; pos_v="0x${v_y}"
    else
        pos_h="0x${h_y}"; pos_v="${h_width}x${v_y}"
    fi
fi
# Native modes avoid forcing 1080p@75 on a different display.
[[ -n "$MON_V" ]] || pos_h=0x0
args=(--output "$MON_H" --primary --rotate normal --pos "$pos_h")
if [[ -n "${MODE_H:-}" ]]; then args+=(--mode "$MODE_H"); else args+=(--auto); fi
[[ -z "${RATE_H:-}" ]] || args+=(--rate "$RATE_H")
if [[ -n "$MON_V" ]]; then
    args+=(--output "$MON_V" --rotate "$ROTATE_V" --pos "$pos_v")
    if [[ -n "${MODE_V:-}" ]]; then args+=(--mode "$MODE_V"); else args+=(--auto); fi
    [[ -z "${RATE_V:-}" ]] || args+=(--rate "$RATE_V")
fi
if ! xrandr "${args[@]}"; then
    # Keep every output on if an explicit mode/rate is unsupported.
    xrandr --output "$MON_H" --auto --primary --rotate normal --pos 0x0 || exit 1
    [[ -z "$MON_V" ]] || xrandr --output "$MON_V" --auto --rotate "$ROTATE_V" \
        "--${VERTICAL_SIDE}-of" "$MON_H" || exit 1
fi
