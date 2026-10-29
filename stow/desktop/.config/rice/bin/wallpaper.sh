#!/usr/bin/env bash
# rice :: wallpaper picker with rofi grid previews

SCRIPT_NAME=${0##*/}
VERSION="1.0.0"

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

function usage() {
    cat <<EOM

Wallpaper selection and restoration.
usage: ${SCRIPT_NAME} [--menu|--set <file>|--restore|--set-theme <file>|--random|--unpin|--help]
Wallpaper directory: ${WALLPAPER_DIR}

EOM
    exit 1
}

function main() {
    local action="menu" file=""

    while (($#)); do
        case $1 in
        -m | --menu) action="menu" ;;
        -s | --set)
            shift
            file="$1"
            action="set"
            ;;
        --set-theme)
            shift
            file="$1"
            action="set-theme"
            ;;
        -u | --unpin) action="unpin" ;;
        -r | --restore) action="restore" ;;
        --random) action="random" ;;
        --version)
            echo "${SCRIPT_NAME} ${VERSION}"
            exit 0
            ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    exit_on_missing_tools feh

    case "$action" in
    menu) menu_wallpaper ;;
    set) set_wallpaper "$file" pin ;;
    set-theme) set_wallpaper "$file" ;;
    restore) restore_wallpaper ;;
    random) random_wallpaper ;;
    unpin) unpin_wallpaper ;;
    esac
}

function list_wallpapers() {
    [ -d "$WALLPAPER_DIR" ] || return 0
    # The "-portrait" variants are derived assets; exclude them from the menu.
    find -L "$WALLPAPER_DIR" -maxdepth 2 -type f ! -iname '*-portrait.*' \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) |
        sort
}

function menu_wallpaper() {
    exit_on_missing_tools rofi
    local chosen file
    local -a files
    mapfile -t files < <(list_wallpapers)
    chosen=$(
        while IFS= read -r file; do
            printf '%s\0icon\x1f%s\n' "$(basename "$file")" "$file"
        done < <(printf '%s\n' "${files[@]}") |
            rofi -dmenu -i -p "wallpaper · $(theme_get name)" -format i -no-custom -show-icons -theme "$ROFI_GRID_THEME"
    )
    [ -z "$chosen" ] && exit 0

    [[ "$chosen" =~ ^[0-9]+$ ]] || return 1
    file="${files[$chosen]}"
    if [ -z "$file" ]; then
        echo "Error: could not find '$chosen' in $WALLPAPER_DIR" >&2
        exit 1
    fi
    set_wallpaper "$file" pin
}

# Use the theme name as the key, never a path or text supplied to rofi.
function wallpaper_key() {
    local name
    name=$(theme_get name default)
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    printf 'wallpaper-theme-%s' "$name"
}

# Migrate the old global choice only to the theme where it was active.
function migrate_wallpaper() {
    [ "$(state_get wallpaper_per_theme 0)" = 1 ] && return 0
    local key file
    key=$(wallpaper_key) || return 1
    file=$(state_get wallpaper '')
    if [ "$(state_get wallpaper_pinned 0)" = 1 ] && [ -f "$file" ]; then
        state_set "$key" "$file" || return 1
    fi
    state_set wallpaper_per_theme 1
}

# --- fit each monitor ---------------------------------------------------
# feh --bg-fill enlarges a single image to cover each monitor. On a portrait
# output (1080x1920), 16:9 artwork needs 1.8x–2.5x enlargement and loses
# all but a central strip, making the image look blurry.
# Give each Xinerama head an image at its exact size
# so feh does not need to rescale it.

WALLFIT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/wallfit"
# Above this enlargement factor, preserve sharpness by containing
# the full artwork over a blurred version of itself.
WALLFIT_MAX_UPSCALE="${RICE_WALL_MAX_UPSCALE:-1.35}"
# Also require substantial cropping. Enlarging matching aspect ratios by
# 1.4x loses no content; excessive cropping is the problem.
WALLFIT_MIN_KEEP="${RICE_WALL_MIN_KEEP:-0.85}"
WALLFIT_VERSION=2

# List heads in the order feh consumes its command-line image arguments.
function xinerama_heads() {
    xdpyinfo -ext XINERAMA 2>/dev/null | awk '/head #/ {print $3}'
}

# Themes may supply portrait artwork; wallgen.sh generates "-portrait" variants.
function portrait_variant() {
    local src="$1" dir base cand
    dir=$(dirname "$src")
    base=$(basename "$src")
    cand="$dir/${base%.*}-portrait.${base##*.}"
    [ -f "$cand" ] && printf '%s' "$cand"
}

# Print the image path at the monitor size, using a disk cache.
function render_for_monitor() {
    local src="$1" W="$2" H="$3"
    local key out Ws Hs fill cheap w h fx fy feather tmp
    local -a mask

    key=$(printf '%s|%s|%sx%s|%s|%s|%s' "$src" "$(stat -c '%Y %s' "$src" 2>/dev/null)" \
        "$W" "$H" "$WALLFIT_MAX_UPSCALE" "$WALLFIT_MIN_KEEP" "$WALLFIT_VERSION" |
        sha256sum | cut -c1-32) || return 1
    out="$WALLFIT_CACHE/$key.png"
    if [ -s "$out" ]; then
        printf '%s' "$out"
        return 0
    fi

    read -r Ws Hs < <(magick identify -format '%w %h\n' "$src[0]" 2>/dev/null)
    [ -n "${Hs:-}" ] && [ "$Ws" -gt 0 ] && [ "$Hs" -gt 0 ] || return 1

    # Simulate --bg-fill: scale to cover, cropping the surplus.
    fill=$(awk -v w="$W" -v h="$H" -v ws="$Ws" -v hs="$Hs" \
        'BEGIN{a=w/ws; b=h/hs; print (a>b?a:b)}')
    # keep = fraction of the artwork retained after cropping.
    cheap=$(awk -v f="$fill" -v m="$WALLFIT_MAX_UPSCALE" -v k="$WALLFIT_MIN_KEEP" \
        -v w="$W" -v h="$H" -v ws="$Ws" -v hs="$Hs" \
        'BEGIN{keep=(w*h)/(f*f*ws*hs); print (f<=m || keep>=k)?1:0}')

    if [ "$cheap" = 1 ]; then
        magick "$src[0]" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
            -strip "$out" 2>/dev/null || return 1
        printf '%s' "$out"
        return 0
    fi

    # Contain the full image without cropping or enlargement over a blurred copy.
    # Fade the strip edges with an alpha ramp to avoid a hard seam.
    read -r w h < <(magick "$src[0]" -resize "${W}x${H}" -format '%w %h\n' info: 2>/dev/null)
    [ -n "${h:-}" ] || return 1
    fx=$(( (W - w) / 2 ))
    fy=$(( (H - h) / 2 ))
    feather=$(( (fx > fy ? fx : fy) / 3 ))
    [ "$feather" -lt 8 ] && feather=8
    [ "$feather" -gt 160 ] && feather=160

    tmp=$(mktemp -d) || return 1

    mask=( -size "${w}x${h}" xc:white )
    if [ "$fy" -gt 0 ]; then
        mask+=( '(' -size "${w}x${feather}" gradient:black-white ')' -gravity north -composite )
        mask+=( '(' -size "${w}x${feather}" gradient:white-black ')' -gravity south -composite )
    fi
    if [ "$fx" -gt 0 ]; then
        mask+=( '(' -size "${h}x${feather}" gradient:black-white -rotate 90 ')' -gravity west -composite )
        mask+=( '(' -size "${h}x${feather}" gradient:white-black -rotate 90 ')' -gravity east -composite )
    fi

    if magick "${mask[@]}" "$tmp/mask.png" 2>/dev/null &&
        magick "$src[0]" -resize "${W}x${H}" "$tmp/mask.png" \
            -alpha off -compose copy_opacity -composite "$tmp/sharp.png" 2>/dev/null &&
        magick \
            '(' "$src[0]" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
                -blur 0x28 -modulate 80,72,100 ')' \
            "$tmp/sharp.png" -gravity center -compose over -composite \
            -alpha remove -alpha off -strip "$out" 2>/dev/null; then
        rm -rf "$tmp"
        printf '%s' "$out"
        return 0
    fi
    rm -rf "$tmp"
    return 1
}

# Apply a separately fitted wallpaper image to each monitor.
function apply_wallpaper() {
    local file="$1" head W H src pv out
    local -a heads rendered

    mapfile -t heads < <(xinerama_heads)
    # Keep the previous behavior if magick or readable Xinerama data is unavailable.
    if ! command -v magick &>/dev/null || [ "${#heads[@]}" -eq 0 ]; then
        feh --no-fehbg --bg-fill "$file"
        return $?
    fi

    mkdir -p "$WALLFIT_CACHE"
    for head in "${heads[@]}"; do
        W="${head%x*}"
        H="${head#*x}"
        src="$file"
        if [ "$H" -gt "$W" ]; then
            pv=$(portrait_variant "$file")
            [ -n "$pv" ] && src="$pv"
        fi
        out=$(render_for_monitor "$src" "$W" "$H") || {
            feh --no-fehbg --bg-fill "$file"
            return $?
        }
        rendered+=( "$out" )
    done

    # Each image already matches its head size; feh does not rescale it.
    feh --no-fehbg --bg-fill "${rendered[@]}" || return 1
    # Remove cached crops for wallpapers that are no longer used.
    find "$WALLFIT_CACHE" -maxdepth 1 -name '*.png' -atime +30 -delete 2>/dev/null
    return 0
}

function set_wallpaper() {
    local file="$1" pin="${2:-}" key previous
    previous=$(state_get wallpaper '')
    migrate_wallpaper || return 1
    key=$(wallpaper_key) || return 1
    file=$(realpath -e -- "$file") || return 1
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "Error: invalid file: '$file'" >&2
        exit 1
    fi

    if ! apply_wallpaper "$file"; then
        echo "Error: feh failed to apply wallpaper" >&2
        exit 1
    fi
    state_set wallpaper "$file"
    if [ "$pin" = "pin" ]; then
        state_set "$key" "$file"
    fi

    # Build the lock screen cache using the same wallpaper.
    if [ "$previous" != "$file" ] && command -v betterlockscreen &>/dev/null; then
        (betterlockscreen -u "$file" --fx dimblur >/dev/null 2>&1 &)
    fi
    notify "wallpaper" "$(basename "$file")" preferences-desktop-wallpaper low
}

# Return control to the theme: clear the override and reapply the active theme.
function unpin_wallpaper() {
    migrate_wallpaper || return 1
    state_clear "$(wallpaper_key)"
    local wall
    wall=$(theme_get wallpaper "")
    if [ -n "$wall" ] && [ -f "$WALLPAPER_DIR/$wall" ]; then
        set_wallpaper "$WALLPAPER_DIR/$wall"
    fi
    notify "wallpaper" "Following the active theme again" preferences-desktop-wallpaper low
}

function restore_wallpaper() {
    migrate_wallpaper || return 1
    local file
    file=$(state_get "$(wallpaper_key)" '')
    if [ ! -f "$file" ]; then
        file="$WALLPAPER_DIR/$(theme_get wallpaper '')"
    fi
    if [ ! -f "$file" ]; then
        file=$(list_wallpapers | head -n1)
    fi
    if [ -f "$file" ]; then
        set_wallpaper "$file"
    else
        xsetroot -solid "$(theme_get bg '#1e1e2e')"
    fi
}

function random_wallpaper() {
    local file
    file=$(list_wallpapers | shuf -n1)
    if [ -z "$file" ]; then
        # No wallpapers: use the active theme's solid background color.
        xsetroot -solid "$(theme_get bg '#1e1e2e')"
        return 0
    fi
    set_wallpaper "$file" pin
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
