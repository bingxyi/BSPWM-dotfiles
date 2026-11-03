#!/usr/bin/env bash
# rice-dotfiles :: geometry and desktops (Universal & Dynamic)
#
# This script adapts to any machine. It applies the maximum resolution,
# respects layouts saved by autorandr (for vertical monitors or
# complex positioning), and distributes bspwm desktops 
# logically: always from left to right.

# Keeps original and precise functions for rate and resolution extraction
preferred_mode() {
    LC_ALL=C xrandr --query | awk -v output="$1" '
        $1 == output && $2 == "connected" { inside=1; next }
        inside && /^[^[:space:]]/ { exit }
        inside && NF > 1 {
            if (first == "") first=$1
            if ($0 ~ /[0-9][*]*[+]/) { print $1; found=1; exit }
        }
        END { if (!found && first != "") print first }
    '
}

max_rate() {
    LC_ALL=C xrandr --query | awk -v output="$1" -v mode="$2" '
        $1 == output && $2 == "connected" { inside=1; next }
        inside && /^[^[:space:]]/ { exit }
        inside && $1 == mode {
            for (i=2; i<=NF; i++) {
                gsub(/[+*]/, "", $i)
                if ($i + 0 > max) max=$i + 0
            }
            if (max > 0) printf "%.2f", max
            exit
        }
    '
}

output_args() {
    local output="$1" mode rate
    mode=$(preferred_mode "$output")
    rate=$(max_rate "$output" "$mode")
    if [ -n "$mode" ] && [ -n "$rate" ]; then
        echo "--output $output --mode $mode --rate $rate"
    else
        echo "--output $output --auto"
    fi
}

# 1. GEOMETRY AND RESOLUTION ARCHITECTURE
# Attempts to load an autorandr profile first (e.g., work dock, vertical screen).
if command -v autorandr &>/dev/null && autorandr --change 2>/dev/null; then
    echo "Physical layout managed and applied by autorandr."
else
    # Automatic fallback: scans all connected outputs and aligns them side by side
    PRIMARY=$(xrandr -q | awk '/ connected/ && /^(eDP|LVDS)/ {print $1; exit}')
    [ -z "$PRIMARY" ] && PRIMARY=$(xrandr -q | awk '/ connected/ {print $1; exit}')

    mapfile -t CONNECTED < <(xrandr -q | awk '/ connected/ {print $1}')
    
    XRANDR_CMD="xrandr"
    PREV_MON=""

    for mon in "${CONNECTED[@]}"; do
        ARGS=$(output_args "$mon")
        if [ "$mon" = "$PRIMARY" ]; then
            XRANDR_CMD="$XRANDR_CMD $ARGS --primary"
        elif [ -n "$PREV_MON" ]; then
            XRANDR_CMD="$XRANDR_CMD $ARGS --right-of $PREV_MON"
        else
            XRANDR_CMD="$XRANDR_CMD $ARGS"
        fi
        PREV_MON="$mon"
    done
    
    eval "$XRANDR_CMD"
fi

# Waits for X11 to settle the new resolutions before applying desktops
sleep 0.5

# 2. GEOMETRIC SORTING (The magic trick)
# Reads xrandr to get the X and Y positions of each active screen and sorts them
# from left to right (and top to bottom in case of vertical tie).
mapfile -t MONITORS_GEOMETRIC < <(
    LC_ALL=C xrandr --query | awk '/ connected/ {
        name=$1
        for(i=2;i<=NF;i++){
            if($i ~ /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/){
                split($i, arr, "+")
                print arr[2], arr[3], name
                break
            }
        }
    }' | sort -k1,1n -k2,2n | awk '{print $3}'
)

NUM_MONS=${#MONITORS_GEOMETRIC[@]}

# 3. DYNAMIC DESKTOP ALLOCATION
# Since monitors are now spatially sorted (left to right),
# workspaces will respect the physical location of the screen in the real world.
if [ "$NUM_MONS" -eq 1 ]; then
    bspc monitor "${MONITORS_GEOMETRIC[0]}" -d 1 2 3 4 5 6 7 8 9 10
elif [ "$NUM_MONS" -eq 2 ]; then
    bspc monitor "${MONITORS_GEOMETRIC[0]}" -d 1 2 3 4 5
    bspc monitor "${MONITORS_GEOMETRIC[1]}" -d 6 7 8 9 10
elif [ "$NUM_MONS" -eq 3 ]; then
    bspc monitor "${MONITORS_GEOMETRIC[0]}" -d 1 2 3
    bspc monitor "${MONITORS_GEOMETRIC[1]}" -d 4 5 6
    bspc monitor "${MONITORS_GEOMETRIC[2]}" -d 7 8 9 10
else
    # Fallback for bizarre setups (4+ monitors)
    for i in "${!MONITORS_GEOMETRIC[@]}"; do
        bspc monitor "${MONITORS_GEOMETRIC[$i]}" -d "W$((i+1))"
    done
fi

# 4. ORPHANED DESKTOPS SANITIZATION
# Monitors that disappeared (cable removed) cannot hold orphaned desktops.
mapfile -t CONNECTED_NOW < <(xrandr -q | awk '/ connected/ {print $1}')
for m in $(bspc query -M --names); do
    ativo=0
    for conn in "${CONNECTED_NOW[@]}"; do
        if [ "$m" = "$conn" ]; then
            ativo=1
            break
        fi
    done
    if [ "$ativo" -eq 0 ]; then
        bspc monitor "$m" -r 2>/dev/null
    fi
done

exit 0
