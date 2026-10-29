# Arch Linux · bspwm rice

![Screenshot — substituir por docs/screenshot.png](docs/screenshot.png)

bspwm + sxhkd, tint2 (Nyx) ou Eww (Vesper), picom e temas compartilhados.

## Dependências

- Instalação: `git`, `stow`, `python` (3.10+), `bash`, `coreutils`, `util-linux`.
- Sessão: `xorg-server`, `xorg-xinit`, `xorg-xrandr`, `xorg-xprop`,
  `xorg-xset`, `xorg-xsetroot`, `xorg-setxkbmap`, `xorg-xdpyinfo`, `xdotool`,
  `bspwm`, `sxhkd`, `picom`, `tint2`, `rofi`, `dunst`, `kitty`, `jq`.
- Painéis: Eww com suporte X11 (AUR), `playerctl`, `python-gobject`,
  `libnotify`, `network-manager-applet`, `blueman`, `polkit-gnome`, `wmctrl`.
- Shell/editor: `zsh`, `neovim`, `starship`, `eza`, `bat`, `fd`, `fzf`,
  `ripgrep`, `zoxide`, `zsh-autosuggestions`, `zsh-syntax-highlighting`.
- Visual: `ttf-jetbrains-mono-nerd`, `inter-font`, `papirus-icon-theme`,
  `xsettingsd`; temas GTK/cursor Catppuccin são opcionais (fallback Adwaita).
- Recursos opcionais: `feh`, `imagemagick`, `betterlockscreen` ou `i3lock`,
  `brightnessctl`, `xclip`, Greenclip (AUR), `pavucontrol`, `power-profiles-daemon`,
  `firefox`, `thunar`, `yazi`, `openvpn`, `flameshot`, `ffmpeg`.
- Verificação adicional: `shellcheck`, `xorg-server-xephyr` ou `xorg-server-xvfb`.
  Nenhum pacote é removido automaticamente; a instalação não altera pacotes do sistema.

## Instalação

```sh
git clone https://github.com/SEU_USUARIO/offsec-dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo pacman -S --needed stow python
./install.sh --dry-run
./install.sh
```

O instalador usa GNU Stow com `--no-folding`, mantém outros arquivos nas pastas
compartilhadas e salva conflitos, inclusive links quebrados, em
`~/.local/state/offsec-dotfiles/backups/`. Cada transação imprime o comando de
restauração. Uma falha reverte os arquivos gerenciados; restaurar depois de
editar arquivos instalados é recusado para preservar essas edições.

```sh
./install.sh --restore /CAMINHO/DO/BACKUP
./install.sh --target /CAMINHO/DE/UM/HOME/DE/TESTE
```

Os arquivos estáticos ficam ligados ao repositório. Arquivos gerados pelas
paletas são arquivos normais, não symlinks: cada instalação os recria com
backup. Estado pessoal (tema escolhido, perfil e mouse) é preservado.

## Uso e atualizações

```sh
./sync.sh                              # git pull --ff-only + instalação + renderização
~/.config/offsec/bin/theme.sh --menu
~/.config/offsec/bin/profile.sh --menu
systemctl --user daemon-reload
systemctl --user enable --now offsec-notification-retention.service
```

Configure um remoto/upstream antes de usar `sync.sh`. Ele recusa alterações
locais pendentes e conflitos de histórico; não usa reset/force. Edite os
arquivos estáticos no repositório ou nos symlinks: as alterações são imediatas.
Após uma atualização, o próximo login usa os scripts novos. Para recarregar
explicitamente a sessão atual, `bspc wm -r` e `Super+Escape` recarregam WM/atalhos.
O compositor já em execução é preservado; sua nova configuração vale no próximo login.

Monitores usam modos nativos e centralização vertical. Ajustes por máquina:

```sh
cp examples/monitors.local.sh ~/.config/bspwm/monitors.local.sh
```

Edite os nomes/modos antes de usar esse exemplo. `Super+Alt+period` abre emojis;
`Super+comma/period` alterna monitores. Wallpapers ficam em `~/Pictures/wallpapers`
e credenciais VPN em `~/vpn`; ambos ficam fora do Git. Sem wallpaper, usa cor sólida.
O launcher Burp exige a instalação licenciada local já existente em
`~/Burpsuite-Professional`; nenhum JAR ou licença é distribuído aqui.

Scripts de integração com SDDM, energia e ajustes do sistema estão em
`~/.config/offsec/system/`; são opcionais e exigem execução separada com sudo.
A instalação principal não os executa, não reinicia serviços e não muda o boot.
O avatar de login é opcional (`~/.config/offsec/login/avatar.png`, fora do Git).
Os fontes SilentSDDM mantêm as licenças em seu diretório.

## Estrutura e validação

```text
stow/desktop/  # WM, painéis, compositor, temas e scripts
stow/shell/    # zsh e inicialização X11
stow/editor/   # Neovim
defaults/     # estado inicial copiado uma vez
scripts/      # instalador e verificador
tests/        # regressões e transações de instalação
docs/         # auditoria e screenshot a adicionar
```

```sh
python3 scripts/check.py
python3 -m unittest discover -s tests -v
git add .
git commit -m "feat: initial bspwm rice structure"
```

Veja [docs/audit.md](docs/audit.md) para o escopo dos testes e as limitações
da validação gráfica neste ambiente.
