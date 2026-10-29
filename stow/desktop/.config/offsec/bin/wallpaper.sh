#!/usr/bin/env bash
# offsec-dotfiles :: seletor de wallpaper com preview em grade (rofi)

SCRIPT_NAME=${0##*/}
VERSION="1.0.0"

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

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
    # As variantes "-portrait" são derivadas, não escolhas: ficam fora do menu.
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

# A chave usa o nome do tema; nunca o caminho ou o texto fornecido ao rofi.
function wallpaper_key() {
    local name
    name=$(theme_get name default)
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    printf 'wallpaper-theme-%s' "$name"
}

# Migra a escolha global antiga somente para o tema em que ela estava ativa.
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

# --- ajuste por monitor ---------------------------------------------------
# feh --bg-fill recebe UMA imagem e amplia até cobrir cada monitor. No monitor
# em pé (1080x1920) uma arte 16:9 precisa de 1,8x a 2,5x de zoom e só uma
# fatia central sobrevive ao corte — daí a sensação de resolução ruim.
# Aqui cada head do Xinerama recebe uma imagem já no tamanho exato dele,
# então o feh não reescala mais nada.

WALLFIT_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/offsec/wallfit"
# Acima deste fator de ampliação, cobrir custa nitidez demais e vale mais
# conter a arte inteira sobre um fundo desfocado dela mesma.
WALLFIT_MAX_UPSCALE="${OFFSEC_WALL_MAX_UPSCALE:-1.35}"
# ...e desde que o corte jogue fora arte demais. Ampliar 1,4x uma arte que já
# tem a proporção do monitor não perde nada; o que estraga é o corte grande.
WALLFIT_MIN_KEEP="${OFFSEC_WALL_MIN_KEEP:-0.85}"
WALLFIT_VERSION=2

# Heads na mesma ordem em que o feh consome os arquivos da linha de comando.
function xinerama_heads() {
    xdpyinfo -ext XINERAMA 2>/dev/null | awk '/head #/ {print $3}'
}

# Um tema pode trazer arte retrato própria; o wallgen.sh gera "-portrait".
function portrait_variant() {
    local src="$1" dir base cand
    dir=$(dirname "$src")
    base=$(basename "$src")
    cand="$dir/${base%.*}-portrait.${base##*.}"
    [ -f "$cand" ] && printf '%s' "$cand"
}

# Imprime o caminho da imagem já no tamanho do monitor; usa cache em disco.
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

    # O que o --bg-fill faria: escala para cobrir, cortando o excedente.
    fill=$(awk -v w="$W" -v h="$H" -v ws="$Ws" -v hs="$Hs" \
        'BEGIN{a=w/ws; b=h/hs; print (a>b?a:b)}')
    # keep = fração da arte que sobrevive a esse corte.
    cheap=$(awk -v f="$fill" -v m="$WALLFIT_MAX_UPSCALE" -v k="$WALLFIT_MIN_KEEP" \
        -v w="$W" -v h="$H" -v ws="$Ws" -v hs="$Hs" \
        'BEGIN{keep=(w*h)/(f*f*ws*hs); print (f<=m || keep>=k)?1:0}')

    if [ "$cheap" = 1 ]; then
        magick "$src[0]" -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
            -strip "$out" 2>/dev/null || return 1
        printf '%s' "$out"
        return 0
    fi

    # Contém a arte inteira (sem corte, sem ampliar) sobre um fundo desfocado
    # dela mesma. As bordas da faixa recebem alfa em rampa: sem emenda dura.
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

# Aplica o wallpaper com uma imagem sob medida para cada monitor.
function apply_wallpaper() {
    local file="$1" head W H src pv out
    local -a heads rendered

    mapfile -t heads < <(xinerama_heads)
    # Sem magick ou sem Xinerama legível, mantém o comportamento antigo.
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

    # Cada arquivo já tem o tamanho exato do seu head: o feh não reescala.
    feh --no-fehbg --bg-fill "${rendered[@]}" || return 1
    # Recortes de wallpapers que não se usa mais não precisam ficar no disco.
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

    # cache do lock screen com o mesmo papel de parede
    if [ "$previous" != "$file" ] && command -v betterlockscreen &>/dev/null; then
        (betterlockscreen -u "$file" --fx dimblur >/dev/null 2>&1 &)
    fi
    notify "wallpaper" "$(basename "$file")" preferences-desktop-wallpaper low
}

# Devolve o controle ao tema: limpa a fixação e reaplica o tema ativo.
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
        # sem wallpapers: fundo sólido com a cor do tema ativo
        xsetroot -solid "$(theme_get bg '#1e1e2e')"
        return 0
    fi
    set_wallpaper "$file" pin
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
