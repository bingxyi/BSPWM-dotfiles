#!/usr/bin/env bash
# offsec-dotfiles :: ajustes de desempenho que exigem root.
#
#   sudo bash ~/.config/offsec/system/install-performance.sh
#
# Tudo aqui é idempotente e faz backup do que substitui. Cada bloco é
# independente: se um falhar, os outros seguem. Nada aqui mexe em bootloader,
# initramfs ou LUKS — a sessão continua recuperável.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0" >&2
    exit 1
fi

USER_NAME="${SUDO_USER:?Run via sudo from the target user account}"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="/root/offsec-perf-backup-$STAMP"
mkdir -p "$BACKUP"
echo "backup dos arquivos substituídos em: $BACKUP"
echo

keep() { [ -f "$1" ] && cp -a "$1" "$BACKUP/" && echo "   guardado: $1"; }
step() { printf '\n\033[1;35m== %s ==\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
step "1/5  Pacotes de desempenho"
# irqbalance  : espalha interrupções pelos 12 threads do Ryzen
# ananicy-cpp : prioriza automaticamente processos interativos sobre lote
# earlyoom    : mata o vilão antes de a memória acabar e travar a sessão
# mesa-utils  : glxinfo, para diagnosticar aceleração depois
PKGS=(irqbalance ananicy-cpp earlyoom mesa-utils xorg-xwininfo xorg-xev xorg-xlsclients)
MISSING=()
for p in "${PKGS[@]}"; do pacman -Q "$p" &>/dev/null || MISSING+=("$p"); done
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "   instalando: ${MISSING[*]}"
    pacman -S --needed --noconfirm "${MISSING[@]}" || echo "   (alguns pacotes falharam; seguindo)"
else
    echo "   todos já instalados"
fi

# ---------------------------------------------------------------------------
step "2/5  Serviços"
for svc in irqbalance ananicy-cpp earlyoom; do
    if systemctl list-unit-files "$svc.service" &>/dev/null; then
        systemctl enable --now "$svc.service" &>/dev/null &&
            echo "   ativo: $svc" || echo "   falhou: $svc"
    fi
done

# ---------------------------------------------------------------------------
step "3/5  sysctl para responsividade de desktop"
# Não se mexe em vm.swappiness: o zram-generator já o define em 180, que é o
# valor certo para swap comprimido em RAM. Baixá-lo pioraria.
keep /etc/sysctl.d/99-offsec-desktop.conf
cat > /etc/sysctl.d/99-offsec-desktop.conf <<'SYSCTL'
# offsec-dotfiles :: responsividade de desktop

# Segura inodes/dentries por mais tempo: navegação e busca de arquivo ficam
# perceptivelmente mais rápidas em um SSD com btrfs.
vm.vfs_cache_pressure = 50

# Limites absolutos em vez de porcentagem: com 16 GB, dirty_ratio=20 deixa
# ~3 GB de escrita suja acumular e a descarga trava o desktop por segundos.
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 134217728

# Jogos, Proton e alguns scanners mapeiam muita coisa.
vm.max_map_count = 2147483642

# Editores e watchers (nvim, IDEs, node) esbarram no limite padrão.
fs.inotify.max_user_watches = 524288
SYSCTL
sysctl --system &>/dev/null && echo "   aplicado" || echo "   falhou ao aplicar"

# ---------------------------------------------------------------------------
step "4/5  Mouse: Xorg deixa de ditar a sensibilidade"
# A GUI (~/.config/offsec/bin/mouse-settings.py) e o mouse.json passam a ser a
# única fonte de verdade. O Xorg fica no neutro para que não haja um "salto"
# de sensibilidade entre o login e o momento em que o mouse.json é reaplicado.
keep /etc/X11/xorg.conf.d/50-mouse-accel.conf
cat > /etc/X11/xorg.conf.d/50-mouse-accel.conf <<'MOUSE'
# offsec-dotfiles :: base neutra do mouse.
#
# A sensibilidade NÃO se ajusta aqui. Quem manda é a GUI:
#   Super + Alt + M      (ou ~/.config/offsec/bin/mouse-settings.py)
# que grava em ~/.config/offsec/mouse.json e reaplica a cada login/hotplug.
#
# Este arquivo só garante um ponto de partida previsível (0.0 = padrão do
# libinput). Deixá-lo em 1.0 fazia o mouse nascer no máximo a cada login.

Section "InputClass"
        Identifier "offsec mouse base"
        MatchDriver "libinput"
        MatchIsPointer "on"
        Option "AccelProfile" "adaptive"
        Option "AccelSpeed" "0.0"
EndSection
MOUSE
echo "   /etc/X11/xorg.conf.d/50-mouse-accel.conf -> neutro (0.0)"

# ---------------------------------------------------------------------------
step "5/5  NVIDIA: liberar o controle do PowerMizer"
# Sem Coolbits o driver aceita 'GPUPowerMizerMode=1' e descarta em silêncio:
# o nvidia-settings responde "assigned value 1" e a leitura seguinte devolve 0.
# Coolbits 28 = 4 (overclock) + 8 (fan) + 16 (clock offset).
keep /etc/X11/xorg.conf.d/20-nvidia-perf.conf
cat > /etc/X11/xorg.conf.d/20-nvidia-perf.conf <<'NVIDIA'
# offsec-dotfiles :: libera atributos de desempenho da GPU ao nvidia-settings.
# Sem isto o PowerMizer não sai do modo adaptativo.
Section "OutputClass"
        Identifier "nvidia perf"
        MatchDriver "nvidia-drm"
        Driver "nvidia"
        Option "Coolbits" "28"
EndSection
NVIDIA
echo "   Coolbits habilitado (vale no próximo início do Xorg)"

cat <<FIM

──────────────────────────────────────────────────────────────────────
Pronto. O que exige reinício da sessão gráfica (logout ou reboot):
  * Coolbits  -> depois dele, 'powerprofile.sh --set performance' passa a
                 fixar o PowerMizer em desempenho máximo. Confira com:
                     ~/.config/offsec/bin/powerprofile.sh --gpu
  * mouse     -> a base neutra do Xorg.

Já valendo agora: pacotes, serviços e sysctl.
Backup do que foi substituído: $BACKUP
──────────────────────────────────────────────────────────────────────
FIM
