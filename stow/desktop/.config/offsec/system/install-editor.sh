#!/usr/bin/env bash
# BSPWM-dotfiles :: make Neovim the system default editor, including through sudo
#
#   sudo bash ~/.config/offsec/system/install-editor.sh
#   sudo bash ~/.config/offsec/system/install-editor.sh --root-snapshot
#
# Without flags, configure the essentials:
#   * EDITOR/VISUAL/SUDO_EDITOR for TTY, SSH, and display manager sessions
#   * sudoers: make sudoedit respect your editor
#
# --root-snapshot is optional, for "sudo nvim" without files or with flags
# (such as "sudo nvim -d a b"), which sudoedit cannot handle. Copy the
# configuration to /root with root ownership; do not symlink to your home.
# A symlink would let root execute Lua writable by user processes.
# A copy avoids that link but must be resynchronized after configuration edits.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo bash $0 [--root-snapshot]" >&2
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
keep() { [ -e "$1" ] && cp -a "$1" "$BACKUP/" && echo "   Backed up: $1"; }

NVIM=$(command -v nvim || echo /usr/bin/nvim)
if [ ! -x "$NVIM" ]; then
    echo "nvim not found at $NVIM" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
step "1/3  Default EDITOR for all sessions"
# pam_env reads /etc/environment for TTY, SSH, and display manager sessions.
# It does not expand variables or execute shell commands.
keep /etc/environment
# Remove this script's previous block before rewriting it (idempotent).
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
step "2/3  sudoers: make sudoedit respect your editor"
# env_editor makes sudoedit use the user's SUDO_EDITOR/VISUAL/EDITOR.
# sudoedit runs the editor with the user UID, never as root.
# The editor= setting is a fallback when none of those variables exists.
SUDOERS=/etc/sudoers.d/10-offsec-editor
TMP=$(mktemp)
cat > "$TMP" <<SUDOEOF
# BSPWM-dotfiles :: sudoedit editor
Defaults env_editor
Defaults editor=$NVIM
SUDOEOF

# Validate sudoers before installing; an invalid file can break sudo access.
if visudo -c -f "$TMP" >/dev/null 2>&1; then
    keep "$SUDOERS"
    install -m 0440 -o root -g root "$TMP" "$SUDOERS"
    if visudo -c >/dev/null 2>&1; then
        echo "   Installed and validated: $SUDOERS"
    else
        echo "   !! /etc/sudoers is invalid — rolling back" >&2
        rm -f "$SUDOERS"
        [ -f "$BACKUP/$(basename $SUDOERS)" ] && cp -a "$BACKUP/$(basename $SUDOERS)" "$SUDOERS"
        visudo -c >/dev/null 2>&1 && echo "   Rollback successful" || echo "   !! Check sudo manually" >&2
    fi
else
    echo "   !! File rejected by visudo; nothing was installed" >&2
fi
rm -f "$TMP"

# ---------------------------------------------------------------------------
step "3/3  Neovim for root"
if [ "$SNAPSHOT" = 0 ]; then
    cat <<SKIP
   Skipped (default).
   'sudo nvim FILE' already uses your configuration through sudoedit;
   the ~/.zshrc function redirects it automatically. The snapshot is only
   needed for 'sudo nvim' without files or with flags. To install:
       sudo bash $0 --root-snapshot
SKIP
else
    echo "   Copying configuration and plugins from $USER_NAME to /root (owned by root)"
    keep /root/.config/nvim
    rm -rf /root/.config/nvim /root/.local/share/nvim/lazy
    install -d -m 0755 /root/.config /root/.local/share/nvim
    cp -a "$USER_HOME/.config/nvim" /root/.config/nvim
    if [ -d "$USER_HOME/.local/share/nvim/lazy" ]; then
        cp -a "$USER_HOME/.local/share/nvim/lazy" /root/.local/share/nvim/lazy
    fi
    chown -R root:root /root/.config/nvim /root/.local/share/nvim
    chmod -R go-w /root/.config/nvim /root/.local/share/nvim
    echo "   Done. Run this command again after changing the configuration."
fi

cat <<FIM

──────────────────────────────────────────────────────────────────────
Verify (opens your Neovim with its theme and plugins to edit a root-owned file):
    sudoedit /etc/fstab
    sudo nvim /etc/fstab        # The zsh function redirects to sudoedit.

/etc/environment takes effect at the next login. For the current session,
~/.config/offsec/env already configures the shell.
Backup: $BACKUP
──────────────────────────────────────────────────────────────────────
FIM
