#!/usr/bin/env bash
# offsec-dotfiles :: central de controle (eww) na direita do monitor primário
#
# A animação exige duas etapas: a janela precisa existir antes de o revealer
# poder deslizar. Abrir e revelar no mesmo instante mostraria o painel já
# inteiro, sem transição — daí o par abrir -> (pequena espera) -> revelar.
#
# Funciona em qualquer perfil: o daemon do eww sobe sob demanda, então a
# central existe mesmo no perfil Nyx, onde a barra é o tint2.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"


function usage() {
    cat <<EOM

Desktop control center.
usage: ${SCRIPT_NAME} [--toggle|--open|--close|--status|--glyph|--help]
    --glyph     Status icon for the bar

EOM
    exit 1
}

# A barra é a única superfície sempre visível: o glifo precisa dizer, de
# relance, se algo está segurando o sistema acordado. DND já tem seu sino.
function print_glyph() {
    local caffeine color glyph
    caffeine=$("$OFFSEC_DIR/bin/caffeine.sh" --status 2>/dev/null)

    if [ "$caffeine" = "on" ]; then
        color=$(theme_get yellow '#c9a86a')
        glyph='\U000f0f8b'
    else
        color=$(theme_get fg_dim '#9c93b0')
        glyph='\U000f062e'
    fi
    printf '<span foreground="%s">%b</span>\n' "$color" "$glyph"
}

function main() {
    local action="toggle"

    while (($#)); do
        case $1 in
        -t | --toggle) action="toggle" ;;
        -o | --open) action="open" ;;
        -c | --close) action="close" ;;
        -s | --status) action="status" ;;
        -g | --glyph) action="glyph" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    glyph) print_glyph ;;
    *) exec "$HOME/.config/offsec/bin/panel.sh" "$action" control ;;
    esac

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
