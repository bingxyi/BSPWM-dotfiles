# rice :: zsh
# Shared X11 and shell environment from ~/.config/rice/env.

[ -r "$HOME/.config/rice/env" ] && source "$HOME/.config/rice/env"

#: --------------------------------------------------------------- history
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

#: ------------------------------------------------------------ rice shortcuts
alias eng='engagement.sh'
alias tgt='target.sh'
alias px='proxy.sh'
alias vpn='vpn.sh'
alias shot='screenshot.sh'
alias theme='theme.sh'

# Change to the active engagement directory.
function cde() {
    local engagement_path
    engagement_path=$(cat "$XDG_DATA_HOME/rice/engagement" 2>/dev/null)
    if [ -z "$engagement_path" ] || [ ! -d "$engagement_path" ]; then
        echo "No active engagement (use: eng --new)" >&2
        return 1
    fi
    cd "$engagement_path" || return 1
}

# $TARGET is always available in the shell.
function target() {
    if [ $# -eq 0 ]; then
        cat "$XDG_DATA_HOME/rice/target" 2>/dev/null
        return 0
    fi
    target.sh --set "$1"
    export TARGET="$1"
}
export TARGET="$(cat "$XDG_DATA_HOME/rice/target" 2>/dev/null)"

# Quick HTTP server in the current directory.
function serve() {
    local port="${1:-8000}"
    echo "http://$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1):$port"
    python -m http.server "$port"
}

# Listener with readline.
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

# yazi with directory change on exit (shortcut: y).
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
# "sudo nvim /etc/foo" opens Neovim as root with $HOME=/root, without your
# plugins, theme, or keymaps. sudoedit runs Neovim as your user with the
# full configuration on a temporary copy, then installs the edited file
# as root when the editor exits.
#
# Pointing root's Neovim at ~/.config/nvim would execute Lua that any
# process running as your user could rewrite. On a machine running
# engagement binaries and third-party plugins, that creates
# a privilege escalation path.
sudo() {
    emulate -L zsh
    if [[ "$1" == (nvim|vim|vi) ]] && (( $# > 1 )); then
        local -a rest=("${@:2}")
        # Redirect only when every argument is a path. Neovim flags
        # (-d, -c, -u, +42) require the original Neovim invocation.
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
