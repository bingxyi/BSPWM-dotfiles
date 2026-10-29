#!/usr/bin/env bash
# Purpose: move the node boundary in the requested direction (tiled or floating)
# Usage: resize.sh <west|south|north|east> [px] [node]
#
# Try the forward edge first to grow the window in the requested direction.
# If there is no neighbor, use the opposite edge to shrink it. Both cases
# move the boundary toward the arrow; floating windows use the first edge.

DIR="${1:-}"
STEP="${2:-40}"
NODE="${3:-focused}"

case "$DIR" in
west) bspc node "$NODE" -z left -"$STEP" 0 || bspc node "$NODE" -z right -"$STEP" 0 ;;
east) bspc node "$NODE" -z right "$STEP" 0 || bspc node "$NODE" -z left "$STEP" 0 ;;
north) bspc node "$NODE" -z top 0 -"$STEP" || bspc node "$NODE" -z bottom 0 -"$STEP" ;;
south) bspc node "$NODE" -z bottom 0 "$STEP" || bspc node "$NODE" -z top 0 "$STEP" ;;
*)
    echo "usage: $(basename "$0") <west|south|north|east> [px] [node]" >&2
    exit 1
    ;;
esac
