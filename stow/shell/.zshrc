# offsec-dotfiles :: zsh
# Ambiente compartilhado com o X vem de ~/.config/offsec/env.

[ -r "$HOME/.config/offsec/env" ] && source "$HOME/.config/offsec/env"

#: --------------------------------------------------------------- histórico
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
mkdir -p "${HISTFILE:h}"
setopt EXTENDED_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS HIST_VERIFY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS
setopt NO_BEEP GLOB_DOTS NUMERIC_GLOB_SORT

#: -------------------------------------------------------------- completion
autoload -Uz compinit
mkdir -p "$XDG_CACHE_HOME/zsh"
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^H' backward-kill-word
bindkey '^[[3~' delete-char

#: ----------------------------------------------------------------- plugins
for plugin in \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
    [ -r "$plugin" ] && source "$plugin"
done
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"
command -v fzf &>/dev/null && source <(fzf --zsh) 2>/dev/null
command -v starship &>/dev/null && eval "$(starship init zsh)"

export FZF_DEFAULT_OPTS="--height 45% --layout=reverse --border=rounded --info=inline"
export FZF_DEFAULT_COMMAND="fd --type f --hidden --follow --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

#: ----------------------------------------------------------------- aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias cat='bat --style=plain --paging=never'
alias catp='bat'
alias grep='grep --color=auto'
alias ip='ip -color=auto'
alias diff='diff --color=auto'
alias df='df -h'
alias free='free -h'
alias mkdir='mkdir -p'
alias v='nvim'
alias vim='nvim'
alias g='git'
alias gs='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias reload='exec zsh'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me; echo'
alias tunip='ip -4 -o addr show tun0 2>/dev/null | awk "{print \$4}" | cut -d/ -f1'

#: ------------------------------------------------------------ offsec atalhos
alias eng='engagement.sh'
alias tgt='target.sh'
alias px='proxy.sh'
alias vpn='vpn.sh'
alias shot='screenshot.sh'
alias theme='theme.sh'

# vai para o engagement ativo
function cde() {
    local engagement_path
    engagement_path=$(cat "$XDG_DATA_HOME/offsec/engagement" 2>/dev/null)
    if [ -z "$engagement_path" ] || [ ! -d "$engagement_path" ]; then
        echo "nenhum engagement ativo (use: eng --new)" >&2
        return 1
    fi
    cd "$engagement_path" || return 1
}

# $TARGET sempre disponível no shell
function target() {
    if [ $# -eq 0 ]; then
        cat "$XDG_DATA_HOME/offsec/target" 2>/dev/null
        return 0
    fi
    target.sh --set "$1"
    export TARGET="$1"
}
export TARGET="$(cat "$XDG_DATA_HOME/offsec/target" 2>/dev/null)"

# servidor http rápido no diretório atual
function serve() {
    local port="${1:-8000}"
    echo "http://$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1):$port"
    python -m http.server "$port"
}

# listener com readline
function listen() {
    local port="${1:-4444}"
    if command -v rlwrap &>/dev/null; then
        rlwrap nc -lvnp "$port"
        return $?
    fi
    nc -lvnp "$port"
}

function urlenc() { python -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
function urldec() { python -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.argv[1]))' "$1"; }
function b64()    { printf '%s' "$1" | base64 -w0; echo; }
function b64d()   { printf '%s' "$1" | base64 -d; echo; }

# yazi com cd ao sair (atalho: y)
function y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)"
    yazi "$@" --cwd-file="$tmp"
    cwd="$(cat -- "$tmp")"
    if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd" || return 1
    fi
    rm -f -- "$tmp"
}

#: ------------------------------------------------------------------ extras
[ -r "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

[ ! -r "$HOME/.local/bin/env" ] || . "$HOME/.local/bin/env"

#: ------------------------------------------------- sudo nvim -> sudoedit
# `sudo nvim /etc/foo` abre um nvim de ROOT, cujo $HOME é /root: nenhum plugin,
# nenhum tema, nenhum keymap seu. `sudoedit` resolve isso pelo lado certo —
# roda o nvim como VOCÊ (config inteira) numa cópia temporária e o sudo
# reinstala o arquivo como root no fim.
#
# O caminho alternativo, apontar o nvim do root para ~/.config/nvim, faria o
# root executar Lua que qualquer coisa rodando como você pode reescrever.
# Numa máquina que roda binário de engagement e plugin de terceiro, isso é
# escalada de privilégio esperando acontecer.
sudo() {
    emulate -L zsh
    if [[ "$1" == (nvim|vim|vi) ]] && (( $# > 1 )); then
        local -a rest=("${@:2}")
        # Só desvia quando todo argumento é caminho. Qualquer flag do nvim
        # (-d para diff, -c, -u, +42) exige o nvim de verdade e segue reto.
        if [[ -z "${(M)rest:#[-+]*}" ]]; then
            command sudoedit "${rest[@]}"
            return
        fi
    fi
    command sudo "$@"
}

# >>> Codex installer >>>
typeset -U path
path=("$HOME/.local/bin" $path)
# <<< Codex installer <<<
