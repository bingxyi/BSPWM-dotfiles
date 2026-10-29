#!/usr/bin/env bash
# offsec-dotfiles :: motor de temas
# Uma definição de cor em ~/.config/offsec/themes/*.conf vira, em um comando,
# kitty + rofi + dunst + tint2 + eww + nvim + GTK + bordas do bspwm + lock.

DEPENDENCIES=(sed awk)
SCRIPT_NAME=${0##*/}
VERSION="1.0.0"
RENDER_ONLY=0

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

function usage() {
    cat <<EOM

Apply a theme to the desktop and applications.
usage: ${SCRIPT_NAME} [--apply <theme>|--menu|--list|--current|--next|--help|--version]

EOM
    exit 1
}

function main() {
    local action="menu" theme=""

    while (($#)); do
        case $1 in
        -a | --apply)
            shift
            theme="$1"
            action="apply"
            ;;
        -m | --menu) action="menu" ;;
        -l | --list) action="list" ;;
        --render-only) RENDER_ONLY=1 ;;
        -c | --current) action="current" ;;
        -n | --next) action="next" ;;
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

    exit_on_missing_tools "${DEPENDENCIES[@]}"

    case "$action" in
    apply) apply_theme "$theme" ;;
    menu)
        exit_on_missing_tools rofi
        menu_theme
        ;;
    list) list_themes ;;
    current) theme_get name "unknown" && echo ;;
    next) next_theme ;;
    esac
}

function list_themes() {
    local file
    for file in "$THEMES_DIR"/*.conf; do
        [ -r "$file" ] || continue
        basename "$file" .conf
    done
}

function menu_theme() {
    local current chosen
    current=$(theme_get name "")
    chosen=$({ list_themes; echo 'Login screen style…'; } | awk -v cur="$current" \
        '{ if ($0==cur) printf "󰸌  %s   (active)\n", $0; else printf "󰸌  %s\n", $0 }' |
        rofi -dmenu -i -p "theme" -theme "$ROFI_MENU_THEME")
    [ -z "$chosen" ] && exit 0
    chosen=$(echo "$chosen" | sed -e 's/^󰸌  //' -e 's/   (active)$//')
    if [ "$chosen" = 'Login screen style…' ]; then
        "$OFFSEC_DIR/bin/login-theme.py" --menu
        return $?
    fi
    apply_theme "$chosen"
}

function next_theme() {
    local current next
    current=$(theme_get name "")
    next=$(list_themes | awk -v cur="$current" '
        { list[NR]=$0 }
        END {
            for (i=1;i<=NR;i++) if (list[i]==cur) { print list[(i % NR)+1]; exit }
            print list[1]
        }')
    apply_theme "$next"
}

function apply_theme() {
    local result
    exec 8>"${XDG_RUNTIME_DIR:-$STATE_DIR}/offsec-theme.lock"
    flock 8 || return 1
    apply_theme_locked "$@"
    result=$?
    flock -u 8
    exec 8>&-
    return "$result"
}

function apply_theme_locked() {
    local theme="$1" src="$THEMES_DIR/$1.conf"

    if [ -z "$theme" ]; then
        echo "Error: theme name is required" >&2
        usage
    fi
    if [ ! -r "$src" ]; then
        echo "Error: theme '$theme' does not exist in $THEMES_DIR" >&2
        exit 1
    fi

    # Only interactive theme changes migrate wallpaper choices or touch the session.
    if (( ! RENDER_ONLY )); then
        ( . "$OFFSEC_DIR/bin/wallpaper.sh"; migrate_wallpaper ) || return 1
    fi

    cp "$src" "$THEME_FILE" || {
        echo "Error: could not write to $THEME_FILE" >&2
        exit 1
    }

    render "$TEMPLATES_DIR/kitty-colors.conf.tpl" "$HOME/.config/kitty/current-theme.conf" || return 1
    render "$TEMPLATES_DIR/rofi-colors.rasi.tpl" "$HOME/.config/rofi/colors.rasi" || return 1
    render "$TEMPLATES_DIR/dunstrc.tpl" "$HOME/.config/dunst/dunstrc" || return 1
    render "$TEMPLATES_DIR/tint2rc.tpl" "$HOME/.config/tint2/tint2rc" || return 1
    render "$TEMPLATES_DIR/eww-colors.scss.tpl" "$HOME/.config/eww/colors.scss" || return 1
    render "$TEMPLATES_DIR/nvim-theme.lua.tpl" "$HOME/.config/nvim/lua/offsec-theme.lua" || return 1
    render "$TEMPLATES_DIR/gtk-settings.ini.tpl" "$HOME/.config/gtk-3.0/settings.ini" || return 1
    render "$TEMPLATES_DIR/xsettingsd.conf.tpl" "$HOME/.config/xsettingsd/xsettingsd.conf" || return 1
    render "$TEMPLATES_DIR/starship.toml.tpl" "$HOME/.config/starship.toml" || return 1
    render "$TEMPLATES_DIR/betterlockscreenrc.tpl" "$HOME/.config/betterlockscreenrc" || return 1

    (( ! RENDER_ONLY )) || return 0
    "$OFFSEC_DIR/bin/login-theme.py" --sync || return 1

    reload_bspwm_colors
    reload_kitty
    reload_dunst
    reload_gtk
    reload_nvim
    reload_bar
    set_theme_wallpaper "$theme" 8>&-

    notify "Theme applied" "$(theme_get pretty "$theme")" preferences-desktop-theme
}

function render() {
    local tpl="$1" out="$2" tmp
    [ -r "$tpl" ] || return 0
    mkdir -p "$(dirname "$out")"

    local -a args=()
    local key value
    while IFS='=' read -r key value; do
        case "$key" in "" | \#*) continue ;; esac
        args+=(-e "s|{{${key}}}|${value}|g")
        args+=(-e "s|{{${key}_raw}}|${value#\#}|g")
    done <"$THEME_FILE"
    args+=(-e "s|{{home}}|${HOME}|g")

    tmp=$(mktemp "$out.XXXXXX") || return 1
    if ! sed "${args[@]}" "$tpl" >"$tmp"; then
        echo "Error: failed to render $tpl" >&2
        rm -f -- "$tmp"
        return 1
    fi
    chmod 644 "$tmp"
    mv -- "$tmp" "$out"
}

function reload_bspwm_colors() {
    command -v bspc &>/dev/null || return 0
    bspc config normal_border_color "$(theme_get border_normal '#313244')"
    bspc config active_border_color "$(theme_get border_normal '#313244')"
    bspc config focused_border_color "$(theme_get border_focused '#cba6f7')"
    bspc config presel_feedback_color "$(theme_get accent '#cba6f7')"
}

function reload_kitty() {
    # kitty recarrega a configuração inteira ao receber SIGUSR1 (sem piscar)
    pkill -USR1 -x kitty 2>/dev/null
    return 0
}

function reload_dunst() {
    if command -v dunstctl &>/dev/null && dunstctl reload 2>/dev/null; then
        return 0
    fi
    pkill -x dunst 2>/dev/null
    (dunst 8>&- &)
    return 0
}

function reload_gtk() {
    local gtk_theme icons
    gtk_theme=$(theme_get gtk_theme "Adwaita-dark")
    icons=$(theme_get gtk_icons "Papirus-Dark")

    if command -v gsettings &>/dev/null; then
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null
        gsettings set org.gnome.desktop.interface icon-theme "$icons" 2>/dev/null
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null
    fi
    pkill -HUP -x xsettingsd 2>/dev/null
    return 0
}

function reload_nvim() {
    local sock
    for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*; do
        [ -S "$sock" ] || continue
        nvim --server "$sock" --remote-send \
            '<C-\><C-N>:OffsecReloadTheme<CR>' 2>/dev/null
    done
    return 0
}

function reload_bar() {
    "$OFFSEC_DIR/bin/bar.sh" --restart >/dev/null 2>&1 8>&- &
    return 0
}

# Cada tema recupera sua própria escolha, ou seu wallpaper padrão.
function set_theme_wallpaper() {
    "$OFFSEC_DIR/bin/wallpaper.sh" --restore
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
