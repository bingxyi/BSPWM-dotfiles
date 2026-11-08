# rice :: initial Kitty shell configuration. Existing user configs are retained.
# Session variables are inherited from ~/.config/rice/env through X11.
if status is-interactive
    set -g fish_greeting

    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != linux; and command -q starship
        starship init fish | source
        enable_transience
    end

    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar clear
    alias claer clear
    alias pamcan pacman
    if test "$TERM" != linux; and command -q eza
        alias ls 'eza --icons'
    end
    if test "$TERM" = xterm-kitty; and command -q kitten
        alias ssh 'kitten ssh'
    end
end
