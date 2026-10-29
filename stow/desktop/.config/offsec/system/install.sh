#!/usr/bin/env bash
# Optional system integration. Main dotfile installation never invokes this.
set -euo pipefail
SRC=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
((EUID == 0)) || { printf 'Run via sudo from your user account\n' >&2; exit 1; }
user_name=${SUDO_USER:?Run via sudo from your user account}
[[ "$user_name" =~ ^[a-z_][a-z0-9_-]*\$?$ ]] || exit 2
command -v visudo >/dev/null
visudo -c >/dev/null
backup=$(mktemp -d /var/backups/offsec-system.XXXXXXXX)
chmod 700 "$backup"
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
sed "s/@USER@/$user_name/g" "$SRC/sudoers-offsec-powerprofile" > "$tmp"
visudo -c -f "$tmp" >/dev/null
sources=("$SRC/offsec-powerprofile" "$tmp" "$SRC/sddm-Xsetup" "$SRC/xorg-mouse-accel.conf")
targets=(/usr/local/bin/offsec-powerprofile /etc/sudoers.d/offsec-powerprofile /etc/sddm/Xsetup /etc/X11/xorg.conf.d/50-mouse-accel.conf)
modes=(755 440 755 644)
printf '#!/usr/bin/env bash\nset -eu\n' > "$backup/restore.sh"
for target in "${targets[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
        mkdir -p "$backup/files${target%/*}"
        cp -a -- "$target" "$backup/files$target"
        printf 'cp -a -- %q %q\n' "$backup/files$target" "$target" >> "$backup/restore.sh"
    else
        printf 'rm -f -- %q\n' "$target" >> "$backup/restore.sh"
    fi
done
chmod 700 "$backup/restore.sh"
rollback() { bash "$backup/restore.sh"; printf 'Rolled back; backup: %s\n' "$backup" >&2; }
trap 'rollback' ERR
for i in "${!targets[@]}"; do
    install -Dm"${modes[$i]}" -o root -g root "${sources[$i]}" "${targets[$i]}"
done
visudo -c >/dev/null
trap - ERR
printf 'Installed; restore: sudo bash %s/restore.sh\n' "$backup"
