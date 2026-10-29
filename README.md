# BSPWM-dotfiles · bspwm rice

An Arch Linux bspwm rice with two sidebar profiles, shared color palettes, and
an application security workflow. Built with sxhkd, picom, rofi, Kitty, Zsh,
Neovim, and optional SDDM integration.

## Features

- **Two desktop profiles:** Nyx uses a lightweight vertical tint2 panel;
  Vesper uses an Eww sidebar. Both share the Eww control center.
- **Coordinated themes:** apply a palette across the terminal, launcher,
  notifications, panels, editor, GTK, window borders, and lock screen.
- **Control center:** Wi-Fi, sound, brightness, notifications, power profiles,
  keep-awake mode, calendar, and engagement context.
- **AppSec tools:** active target and engagement tracking, proxy and VPN helpers,
  evidence screenshots, and Neovim commands for notes and Semgrep results.
- **Monitor support:** native display modes, vertical centering, portrait
  wallpapers, and optional machine-specific overrides.
- **Reversible installation:** GNU Stow symlinks, conflict backups, rollback on
  failure, and preservation of personal theme, profile, and mouse settings.

## Dependencies

Install the tools needed for the features you plan to use. The dotfile installer
does not install or remove system packages.

| Component | Packages and tools |
| --- | --- |
| Installer | `git`, `stow`, Python 3.10+, `bash`, `coreutils`, `util-linux` |
| X11 session | `xorg-server`, `xorg-xinit`, `xorg-xrandr`, `xorg-xprop`, `xorg-xset`, `xorg-xsetroot`, `xorg-setxkbmap`, `xorg-xdpyinfo`, `xdotool` |
| Desktop | `bspwm`, `sxhkd`, `picom`, `tint2`, `rofi`, `dunst`, `kitty`, `jq` |
| Panels and integration | Eww with X11 support (AUR), `playerctl`, `python-gobject`, `libnotify`, `network-manager-applet`, `blueman`, `polkit-gnome`, `wmctrl` |
| Shell and editor | `zsh`, `neovim`, `starship`, `eza`, `bat`, `fd`, `fzf`, `ripgrep`, `zoxide`, `zsh-autosuggestions`, `zsh-syntax-highlighting` |
| Fonts and appearance | `ttf-jetbrains-mono-nerd`, `inter-font`, `papirus-icon-theme`, `xsettingsd` |
| Optional features | `feh`, `imagemagick`, `betterlockscreen` or `i3lock`, `brightnessctl`, `xclip`, Greenclip (AUR), `pavucontrol`, `power-profiles-daemon`, `firefox`, `thunar`, `yazi`, `openvpn`, `flameshot`, `ffmpeg` |

Catppuccin GTK and cursor themes are optional; palettes provide Adwaita fallbacks.

## Installation

Clone the repository to a permanent location: installed static files link back
to this checkout.

```sh
git clone https://github.com/bingxyi/BSPWM-dotfiles.git ~/BSPWM-dotfiles
cd ~/BSPWM-dotfiles
sudo pacman -S --needed git stow python
./install.sh --dry-run
./install.sh
```

Install the session dependencies before logging into bspwm. Select bspwm in your
display manager, or use `startx` with the installed `.xinitrc`.

The installer deploys the desktop, shell, and editor packages with GNU Stow's
`--no-folding` option, keeping unrelated files in shared directories. It backs up
conflicts, including broken symlinks, under
`~/.local/state/offsec-dotfiles/backups/` and prints the exact restore command.
Failed deployments roll back managed files. Later restoration refuses to
overwrite files changed since installation.

```sh
./install.sh --restore /PATH/TO/BACKUP
./install.sh --target /PATH/TO/EXISTING/TEST/HOME
```

Palette-generated files are regular files recreated with backups during
installation. Existing personal settings for the selected theme, profile, and
mouse are preserved. The internal configuration directory remains
`~/.config/offsec/`.

## Everyday use

Open the theme and profile menus from a terminal:

```sh
~/.config/offsec/bin/theme.sh --menu
~/.config/offsec/bin/profile.sh --menu
```

Nyx is the initial profile. Switch to Vesper for the Eww sidebar, or select a
profile directly:

```sh
~/.config/offsec/bin/profile.sh --set vesper
~/.config/offsec/bin/profile.sh --set nyx
```

Enable the optional user service for notification retention:

```sh
systemctl --user daemon-reload
systemctl --user enable --now offsec-notification-retention.service
```

### Keyboard shortcuts

`Super` is the main modifier. Press `Super+/` for the complete shortcut list.

| Shortcut | Action |
| --- | --- |
| `Super+Return` | Open Kitty |
| `Super+D` | Open the application launcher |
| `Super+C` | Toggle the control center |
| `Super+O` | Open the AppSec tools menu |
| `Super+1` through `Super+0` | Focus a workspace |
| `Super+H/J/K/L` | Move window focus |
| `Super+Shift+H/J/K/L` | Move the focused window |
| `Super+Comma` / `Super+Period` | Switch monitors |
| `Super+Alt+Period` | Open the emoji picker |
| `Super+Alt+M` | Open mouse preferences |
| `Print` | Select and annotate a screenshot |
| `Super+Escape` | Reload sxhkd shortcuts |

### Themes, monitors, and personal files

Edit palettes in `stow/desktop/.config/offsec/themes/` and generated-file sources
in `stow/desktop/.config/offsec/templates/`. Session variables live in
`stow/desktop/.config/offsec/env`.

For monitor overrides, inspect your outputs and copy the example:

```sh
xrandr --query
cp examples/monitors.local.sh ~/.config/bspwm/monitors.local.sh
```

Adjust output names, modes, refresh rates, and rotation for your hardware before
applying the configuration. The local override stays outside Git.

Wallpapers belong in `~/Pictures/wallpapers`, VPN credentials in `~/vpn`, and
engagements in `~/engagements`. These personal files remain outside the
repository. Without a wallpaper, the desktop uses the theme's solid background.

The Burp Suite Professional launcher expects your existing licensed installation
in `~/Burpsuite-Professional`. This repository does not distribute a JAR or license.

## Updates

With a configured remote and upstream branch, run:

```sh
cd ~/BSPWM-dotfiles
./sync.sh
```

The script performs `git pull --ff-only`, redeploys the packages, and renders the
theme templates. It refuses pending local changes and divergent history. Commit
or stash edits before updating.

Changes to symlinked static files take effect as their applications read them.
New session scripts run at the next login. To reload bspwm explicitly, run
`bspc wm -r`; use `Super+Escape` to reload sxhkd. A running compositor is kept
alive, so its updated configuration takes effect at the next login.

## Optional system integration

SDDM, system editor, power, and performance helpers are installed under
`~/.config/offsec/system/`. Review the relevant script before running it
separately with `sudo`. The main dotfile installer does not invoke these helpers,
restart system services, or change boot settings.

A custom login avatar can be placed at `~/.config/offsec/login/avatar.png`;
it is excluded from Git. The bundled SilentSDDM sources retain their upstream
documentation, attribution, and licenses in
`stow/desktop/.config/offsec/login/silent-offsec/`.
