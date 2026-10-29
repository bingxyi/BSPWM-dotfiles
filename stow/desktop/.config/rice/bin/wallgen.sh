#!/usr/bin/env bash
# rice :: generate an abstract wallpaper from a theme palette
# Provide a default for themes without their own artwork.
# Usage: wallgen.sh <theme> [output.png] | --all | --force <theme>
set -euo pipefail

. "$HOME/.config/rice/bin/lib.sh"

LAND_W=1920; LAND_H=1080
# Generate separate artwork at the portrait monitor's native resolution
# to avoid the enlargement feh would apply to a 16:9 image.
PORT_W="${RICE_WALL_PORTRAIT_W:-1080}"
PORT_H="${RICE_WALL_PORTRAIT_H:-1920}"
# Source canvas for the glows. Keep it wide enough for the shifted crop;
# a crop extending beyond an edge produces a black strip.
GLOW=3840

WALLGEN_TMP=""
trap 'rm -rf "${WALLGEN_TMP:-}"' EXIT

function color_of() {
    local theme="$1" key="$2" fallback="$3"
    awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/,""); print; exit}' \
        "$THEMES_DIR/$theme.conf" 2>/dev/null | grep . || printf '%s' "$fallback"
}

# Shifted crop within the canvas; offsets are fractions of the surplus.
function glow() {
    local w="$1" h="$2" color="$3" dx="$4" dy="$5" scale="$6" out="$7"
    magick -size ${GLOW}x${GLOW} radial-gradient:"$color"-black \
        -gravity center -crop ${w}x${h}${dx}${dy} +repage \
        -evaluate multiply "$scale" "$out"
}

# Use the same recipe at any aspect ratio; do not assume 16:9.
function render_canvas() {
    local w="$1" h="$2" bg="$3" bg_dim="$4" accent="$5" accent_alt="$6" out="$7"
    # A RETURN trap would outlive this function and fire in its caller,
    # where $tmp is out of scope. Use explicit cleanup and an EXIT trap.
    local tmp; tmp=$(mktemp -d); WALLGEN_TMP="$tmp"

    # Base: a diagonal gradient from the light background to the deep background.
    magick -size ${h}x${w} gradient:"$bg"-"$bg_dim" -rotate 90 \
        -resize ${w}x${h}\! "$tmp/base.png"

    # Two radial glows. The screen blend adds light: gradient black adds nothing,
    # so only the colored center brightens and retains its hue.
    glow "$w" "$h" "$accent"     +480 +300 0.34 "$tmp/g1.png"
    glow "$w" "$h" "$accent_alt" -560 -340 0.20 "$tmp/g2.png"

    magick "$tmp/base.png" \
        "$tmp/g1.png" -compose screen -composite \
        "$tmp/g2.png" -compose screen -composite \
        -attenuate 0.4 +noise Gaussian \
        -modulate 100,104,100 \
        -quality 94 "$tmp/lit.png"

    # Soft vignette: darken only the corners while retaining the glow.
    magick -size ${w}x${h} radial-gradient:white-'#5e5e5e' "$tmp/vig.png"
    magick "$tmp/lit.png" "$tmp/vig.png" -compose multiply -composite \
        -quality 94 "$out"

    rm -rf "$tmp"; WALLGEN_TMP=""
}

# The portrait variant name is shared with wallpaper.sh.
function portrait_path() {
    local out="$1"
    printf '%s-portrait.%s' "${out%.*}" "${out##*.}"
}

function load_colors() {
    local theme="$1"
    BG=$(color_of "$theme" bg '#1e1e2e')
    BG_DIM=$(color_of "$theme" bg_dim '#11111b')
    ACCENT=$(color_of "$theme" accent '#cba6f7')
    ACCENT_ALT=$(color_of "$theme" accent_alt "$ACCENT")
}

function generate() {
    local theme="$1"
    local out="${2:-$WALLPAPER_DIR/$(color_of "$theme" wallpaper "$theme.png")}"
    local portrait
    load_colors "$theme"

    mkdir -p "$(dirname "$out")"
    portrait=$(portrait_path "$out")

    render_canvas "$LAND_W" "$LAND_H" "$BG" "$BG_DIM" "$ACCENT" "$ACCENT_ALT" "$out"
    render_canvas "$PORT_W" "$PORT_H" "$BG" "$BG_DIM" "$ACCENT" "$ACCENT_ALT" "$portrait"

    printf '%s\n%s\n' "$out" "$portrait"
}

# The 16:9 artwork already exists; generate only its portrait variant.
function generate_portrait() {
    local theme="$1" out="$2" portrait
    load_colors "$theme"
    portrait=$(portrait_path "$out")
    render_canvas "$PORT_W" "$PORT_H" "$BG" "$BG_DIM" "$ACCENT" "$ACCENT_ALT" "$portrait"
    printf '%s\n' "$portrait"
}

FORCE=0
[ "${1:-}" = "--force" ] && { FORCE=1; shift; }

case "${1:-}" in
--all)
    for f in "$THEMES_DIR"/*.conf; do
        t=$(basename "$f" .conf)
        w="$WALLPAPER_DIR/$(color_of "$t" wallpaper "$t.png")"
        p=$(portrait_path "$w")
        if [ "$FORCE" = 1 ] || [ ! -f "$w" ]; then
            generate "$t"
        elif [ ! -f "$p" ]; then
            generate_portrait "$t" "$w"
        else
            printf 'Already exists, kept: %s\n' "$w"
        fi
    done
    ;;
-h|--help|'') sed -n '2,5p' "$0" ;;
*) generate "$@" ;;
esac
