#!/usr/bin/env bash
# Purpose: move a divisória do nó na direção informada (tiled e floating)
# Usage: resize.sh <west|south|north|east> [px] [node]
#
# A borda "da frente" é tentada primeiro (a janela cresce na direção); se não
# houver vizinho desse lado, usa a borda oposta (a janela encolhe). Em ambos os
# casos a divisória anda para o lado da seta. Em floating a primeira sempre vale.

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
