#!/usr/bin/env bash
# rice :: performance settings requiring root
#
#   sudo bash ~/.config/rice/system/install-performance.sh
#
# Back up replaced files and keep each step idempotent. Each block is
# independent, so a failure does not stop the remaining blocks.
# Leave the bootloader, initramfs, and LUKS settings untouched.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo bash $0" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:?Run via sudo from the target user account}"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="/root/rice-perf-backup-$STAMP"
mkdir -p "$BACKUP"
echo "Replaced files backed up to: $BACKUP"
echo

keep() { [ -f "$1" ] && cp -a "$1" "$BACKUP/" && echo "   Backed up: $1"; }
step() { printf '\n\033[1;35m== %s ==\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
step "1/5  Performance packages"
# irqbalance  : distribute interrupts across the Ryzen's twelve threads
# ananicy-cpp : prioritize interactive processes over batch work
# earlyoom    : terminate memory-hungry processes before the session freezes
# mesa-utils  : provide glxinfo for acceleration diagnostics
PKGS=(irqbalance ananicy-cpp earlyoom mesa-utils xorg-xwininfo xorg-xev xorg-xlsclients)
MISSING=()
for p in "${PKGS[@]}"; do pacman -Q "$p" &>/dev/null || MISSING+=("$p"); done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "   Installing: ${MISSING[*]}"
    pacman -S --needed --noconfirm "${MISSING[@]}" || echo "   (Some packages failed; continuing)"
else
    echo "   All packages already installed"
fi

# ---------------------------------------------------------------------------
step "2/5  Services"
for svc in irqbalance ananicy-cpp earlyoom; do
    if systemctl list-unit-files "$svc.service" &>/dev/null; then
        systemctl enable --now "$svc.service" &>/dev/null &&
            echo "   Active: $svc" || echo "   Failed: $svc"
    fi
done

# ---------------------------------------------------------------------------
step "3/5  sysctl for desktop responsiveness"
# Leave vm.swappiness unchanged: zram-generator already sets it to 180
# for compressed RAM swap. Lowering it would undermine that setup.
keep /etc/sysctl.d/99-rice-desktop.conf
cat > /etc/sysctl.d/99-rice-desktop.conf <<'SYSCTL'
# rice :: desktop responsiveness

# Retain inodes/dentries longer to speed up directory browsing
# and file searches on a Btrfs SSD.
vm.vfs_cache_pressure = 50

# Use absolute limits: with 16 GB of RAM, dirty_ratio=20 allows about
# 3 GB of dirty writes to accumulate, causing long desktop stalls on flush.
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 134217728

# Games, Proton, and some scanners use many memory mappings.
vm.max_map_count = 2147483642

# Editors and watchers (Neovim, IDEs, Node) can exceed the default limit.
fs.inotify.max_user_watches = 524288
SYSCTL
sysctl --system &>/dev/null && echo "   Applied" || echo "   Failed to apply"

# ---------------------------------------------------------------------------
step "4/5  Mouse: use a neutral Xorg sensitivity baseline"
# The GUI (~/.config/rice/bin/mouse-settings.py) and mouse.json own
# sensitivity settings. Keep the Xorg baseline neutral to avoid a jump
# between login and the reapplication of mouse.json.
keep /etc/X11/xorg.conf.d/50-mouse-accel.conf
cat > /etc/X11/xorg.conf.d/50-mouse-accel.conf <<'MOUSE'
# rice :: neutral mouse baseline
#
# Adjust sensitivity through the GUI:
#   Super + Alt + M (or ~/.config/rice/bin/mouse-settings.py)
# It saves ~/.config/rice/mouse.json and reapplies it at login/hotplug.
#
# This file sets a predictable baseline (0.0 = libinput default).
# Using 1.0 started the mouse at maximum speed on every login.

Section "InputClass"
        Identifier "rice mouse base"
        MatchDriver "libinput"
        MatchIsPointer "on"
        Option "AccelProfile" "adaptive"
        Option "AccelSpeed" "0.0"
EndSection
MOUSE
echo "   /etc/X11/xorg.conf.d/50-mouse-accel.conf -> neutral (0.0)"

# ---------------------------------------------------------------------------
step "5/5  NVIDIA: enable PowerMizer control"
# Without Coolbits, the driver accepts GPUPowerMizerMode=1 but discards it:
# nvidia-settings reports "assigned value 1", yet the next read returns 0.
# Coolbits 28 = 4 (overclock) + 8 (fan) + 16 (clock offset).
keep /etc/X11/xorg.conf.d/20-nvidia-perf.conf
cat > /etc/X11/xorg.conf.d/20-nvidia-perf.conf <<'NVIDIA'
# rice :: allow nvidia-settings to adjust GPU performance attributes
# PowerMizer requires this to leave adaptive mode.
Section "OutputClass"
        Identifier "nvidia perf"
        MatchDriver "nvidia-drm"
        Driver "nvidia"
        Option "Coolbits" "28"
EndSection
NVIDIA
echo "   Coolbits enabled (takes effect at the next Xorg startup)"

cat <<FIM

──────────────────────────────────────────────────────────────────────
Done. Changes requiring a new graphical session (logout or reboot):
  * Coolbits  -> allows 'powerprofile.sh --set performance' to pin
                 PowerMizer to maximum performance. Verify with:
                     ~/.config/rice/bin/powerprofile.sh --gpu
  * mouse     -> the neutral Xorg baseline.

Already active: packages, services, and sysctl settings.
Replaced files backed up to: $BACKUP
──────────────────────────────────────────────────────────────────────
FIM
