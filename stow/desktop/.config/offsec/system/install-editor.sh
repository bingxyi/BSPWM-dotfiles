#!/usr/bin/env bash
# offsec-dotfiles :: nvim como editor padrão do sistema, inclusive sob sudo.
#
#   sudo bash ~/.config/offsec/system/install-editor.sh
#   sudo bash ~/.config/offsec/system/install-editor.sh --root-snapshot
#
# Sem flags faz o essencial e seguro:
#   * EDITOR/VISUAL/SUDO_EDITOR para toda sessão (TTY, SSH, display manager)
#   * sudoers: sudoedit honra o SEU editor
#
# --root-snapshot é OPCIONAL e serve só para 'sudo nvim' sem arquivo ou com
# flags (ex.: 'sudo nvim -d a b'), que o sudoedit não cobre. Ele COPIA a
# config para /root com dono root — não cria symlink para o seu $HOME.
# O symlink faria o root executar Lua que qualquer processo seu pode
# reescrever; a cópia quebra esse elo (o custo é ressincronizar quando você
# mexer na config).
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0 [--root-snapshot]" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:?Run via sudo from the target user account}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)
SNAPSHOT=0
[ "${1:-}" = "--root-snapshot" ] && SNAPSHOT=1

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="/root/offsec-editor-backup-$STAMP"
mkdir -p "$BACKUP"

step() { printf '\n\033[1;35m== %s ==\033[0m\n' "$1"; }
keep() { [ -e "$1" ] && cp -a "$1" "$BACKUP/" && echo "   guardado: $1"; }

NVIM=$(command -v nvim || echo /usr/bin/nvim)
if [ ! -x "$NVIM" ]; then
    echo "nvim não encontrado em $NVIM" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
step "1/3  EDITOR padrão para toda a sessão"
# /etc/environment é lido pelo pam_env: vale em TTY, SSH e display manager,
# não só no shell interativo. Sem expansão de variável e sem executar nada.
keep /etc/environment
# remove um bloco anterior deste script antes de reescrever (idempotência)
sed -i '/^# >>> offsec-editor >>>$/,/^# <<< offsec-editor <<<$/d' /etc/environment
cat >> /etc/environment <<ENVEOF
# >>> offsec-editor >>>
EDITOR=$NVIM
VISUAL=$NVIM
SUDO_EDITOR=$NVIM
# <<< offsec-editor <<<
ENVEOF
echo "   EDITOR/VISUAL/SUDO_EDITOR = $NVIM"

# ---------------------------------------------------------------------------
step "2/3  sudoers: sudoedit passa a honrar o seu editor"
# env_editor faz o sudoedit usar SUDO_EDITOR/VISUAL/EDITOR do usuário.
# Isso NÃO é escalada: o sudoedit roda o editor com o UID do usuário, nunca
# como root. 'editor=' é só o fallback para quando nenhuma delas existir.
SUDOERS=/etc/sudoers.d/10-offsec-editor
TMP=$(mktemp)
cat > "$TMP" <<SUDOEOF
# offsec-dotfiles :: editor do sudoedit
Defaults env_editor
Defaults editor=$NVIM
SUDOEOF

# NUNCA instalar sudoers sem validar: um arquivo inválido pode trancar o sudo.
if visudo -c -f "$TMP" >/dev/null 2>&1; then
    keep "$SUDOERS"
    install -m 0440 -o root -g root "$TMP" "$SUDOERS"
    if visudo -c >/dev/null 2>&1; then
        echo "   instalado e validado: $SUDOERS"
    else
        echo "   !! /etc/sudoers ficou inválido — revertendo" >&2
        rm -f "$SUDOERS"
        [ -f "$BACKUP/$(basename $SUDOERS)" ] && cp -a "$BACKUP/$(basename $SUDOERS)" "$SUDOERS"
        visudo -c >/dev/null 2>&1 && echo "   revertido com sucesso" || echo "   !! confira o sudo manualmente" >&2
    fi
else
    echo "   !! arquivo recusado pelo visudo; nada foi instalado" >&2
fi
rm -f "$TMP"

# ---------------------------------------------------------------------------
step "3/3  nvim do root"
if [ "$SNAPSHOT" = 0 ]; then
    cat <<SKIP
   pulado (padrão).
   'sudo nvim ARQUIVO' já usa a sua config via sudoedit — a função do
   ~/.zshrc desvia sozinha. O snapshot só faz falta para 'sudo nvim' sem
   arquivo ou com flags. Para instalar:
       sudo bash $0 --root-snapshot
SKIP
else
    echo "   copiando config e plugins de $USER_NAME para /root (dono root)"
    keep /root/.config/nvim
    rm -rf /root/.config/nvim /root/.local/share/nvim/lazy
    install -d -m 0755 /root/.config /root/.local/share/nvim
    cp -a "$USER_HOME/.config/nvim" /root/.config/nvim
    if [ -d "$USER_HOME/.local/share/nvim/lazy" ]; then
        cp -a "$USER_HOME/.local/share/nvim/lazy" /root/.local/share/nvim/lazy
    fi
    chown -R root:root /root/.config/nvim /root/.local/share/nvim
    chmod -R go-w /root/.config/nvim /root/.local/share/nvim
    echo "   pronto. Ressincronize com este mesmo comando quando mudar a config."
fi

cat <<FIM

──────────────────────────────────────────────────────────────────────
Confira (abre o SEU nvim, com tema e plugins, editando um arquivo de root):
    sudoedit /etc/fstab
    sudo nvim /etc/fstab        # a função do zsh desvia para sudoedit

O /etc/environment vale a partir do próximo login. Nesta sessão o
~/.config/offsec/env já cobre o shell.
Backup: $BACKUP
──────────────────────────────────────────────────────────────────────
FIM
