# bspwm rice

An Arch Linux bspwm with two sidebar profiles, shared color palettes, and
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
- **Monitor support:** native resolutions and supported refresh rates, laptop
  HDMI/DP hotplug, saved portrait layouts, and lossless desktop migration.
- **Reversible installation:** editable regular files, conflict backups, rollback on
  failure, and preservation of personal theme, profile, and mouse settings.

## Dependencies

Install the tools needed for the features you plan to use. The dotfile installer
does not install or remove system packages.

| Component | Packages and tools |
| --- | --- |
| Installer | `git`, Python 3.10+, `gcc` (FPS limiter), `bash`, `coreutils`, `util-linux` |
| X11 session | `xorg-server`, `xorg-xinit`, `xorg-xrandr`, `xorg-xinput`, `xorg-xprop`, `xorg-xset`, `xorg-xsetroot`, `xorg-setxkbmap`, `xorg-xdpyinfo`, `xdotool` |
| Desktop | `bspwm`, `sxhkd`, `picom`, `tint2`, `rofi`, `dunst`, `kitty`, `jq` |
| Panels and integration | Eww with X11 support (AUR), `playerctl`, `python-gobject`, `python-cairo`, `gtk3`, `libnotify`, `network-manager-applet`, `blueman`, `polkit-gnome`, `wmctrl` |
| Shell and editor | `fish` (Kitty shell), `zsh`, `neovim`, `starship`, `eza`, `bat`, `fd`, `fzf`, `ripgrep`, `zoxide`, `zsh-autosuggestions`, `zsh-syntax-highlighting` |
| Audio, Bluetooth and network | `pipewire`, `pipewire-pulse`, `wireplumber`, `bluez`, `bluez-utils`, `networkmanager` |
| Fonts and appearance | `ttf-jetbrains-mono-nerd`, `inter-font`, `papirus-icon-theme`, `xsettingsd` |
| Optional features | `feh`, `imagemagick`, `betterlockscreen` or `i3lock`, `brightnessctl`, `xclip`, Greenclip (AUR), `pavucontrol`, `power-profiles-daemon`, `firefox`, `thunar`, `yazi`, `openvpn`, `flameshot`, `ffmpeg` |

Catppuccin GTK and cursor themes are optional; palettes provide Adwaita fallbacks.

## Installation

For migration from the notebook to another desktop, follow the
[portability checklist and verified environment](docs/portability.md).

Clone the repository as your versioned distribution source. Installation copies
regular files into the standard application directories; edit the installed code
directly in `~/.config` without changing the checkout automatically.

```sh
git clone https://github.com/bingxyi/BSPWM-dotfiles.git ~/rice
cd ~/rice
sudo pacman -S --needed git python
./install.sh --dry-run
./install.sh
```

Install the session dependencies before logging into bspwm. Select bspwm in your
display manager, or use `startx` with the installed `.xinitrc`.

The installer deploys desktop, shell, and editor as independent regular files,
keeping unrelated files in shared directories. The source directories retain the
historical `stow/` name, but GNU Stow is no longer used or required. Templates
are rendered in staging before any live file moves. Executable permissions are
preserved and individual replacements are atomic. It backs up
conflicts, including old or broken symlinks, under
`~/.local/state/rice/backups/` and prints the exact restore command.
When migrating old links, `resolved/` also stores their actual file contents.
Failed deployments roll back managed files. Later restoration refuses to
overwrite files changed since installation.

```sh
./install.sh --restore /PATH/TO/BACKUP
./install.sh --target /PATH/TO/EXISTING/TEST/HOME
```

Palette-generated files are regular files recreated with backups during
installation. Existing personal settings for the selected theme, profile, and
mouse under the `rice` namespace are preserved. The published configuration uses
`~/.config/rice/`. An old notebook `local.sh` using `$HOME/.config/offsec/bin`
is backed up and updated to use the new scripts. Its screen-lock, battery,
and power-saving settings remain in place. A legacy autorandr invocation in
that hook is disabled so it cannot race the new monitor controller.

On an existing bspwm setup, retain the current workspace/bar monitor preference:

```sh
cd ~/rice
./install.sh --adopt-monitor-layout --dry-run
./install.sh --adopt-monitor-layout
```

This creates a private `~/.config/bspwm/monitors.local.sh` only if none exists.
The preferred monitor is optional: unplugging it automatically selects an
available display. The installer checks core session dependencies before
changing the real home; it does not install packages or restart the session.
English UI uses the portable `C.UTF-8` locale; set `RICE_LANG` if a different
generated locale is wanted.

## Everyday use

Open the theme and profile menus from a terminal:

```sh
~/.config/rice/bin/theme.sh --menu
~/.config/rice/bin/profile.sh --menu
```

Nyx is the initial profile. Switch to Vesper for the Eww sidebar, or select a
profile directly:

```sh
~/.config/rice/bin/profile.sh --set vesper
~/.config/rice/bin/profile.sh --set nyx
```

Enable the optional user service for notification retention:

```sh
systemctl --user daemon-reload
systemctl --user enable --now rice-notification-retention.service
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

Edit active palettes in `~/.config/rice/themes/`, templates in
`~/.config/rice/templates/`, scripts in `~/.config/rice/bin/`, and session
variables in `~/.config/rice/env`. Edit `~/.config/bspwm/bspwmrc` and
`~/.config/sxhkd/sxhkdrc` for WM behavior and binds. The matching `~/rice/stow/`
paths are distribution sources; reconcile your changes there if you want to
version or publish them. Generated colors are recreated from the templates.

The installed `monitors.sh` automatically handles one, two, or more monitors.
It uses each screen's preferred resolution and highest advertised refresh rate,
with a driver-selected rate fallback if the GPU/dock cannot sustain that mix.
Complete active layouts retain positions and rotation. New layouts extend side
by side; disconnected preferred outputs are never required. Matching autorandr
profiles are respected, but merely having autorandr installed does not suppress
automatic detection. Save portrait/stacked/mirrored arrangements with
`autorandr --save work` after setting them up.

Ten named workspaces remain available to `Super+1` through `Super+0`: 1–6 on
the primary/bar monitor and 7–10 on the other monitors (all ten on a single
screen). Existing desktop IDs, windows, and personal desktops are moved when
a cable is removed rather than being reset. A session watcher sleeps on RandR
events, with a 15-second safety check for lid changes. With the lid closed and
an external monitor connected, the external display is used.

Preview, apply, or inspect the monitor configuration:

```sh
~/.config/bspwm/monitors.sh --plan
~/.config/bspwm/monitors.sh
tail ~/.local/state/rice-monitors.log
```

The old `monitors.sh` is backed up and replaced during installation. To keep a
completely custom script instead, use `./install.sh --keep-monitors` on each
deployment. Automatic hotplug is enabled only for the supplied controller.

For optional private preferences, inspect your outputs and copy the example:

```sh
xrandr --query
cp examples/monitors.local.sh ~/.config/bspwm/monitors.local.sh
```

Set the preferred monitor/order if needed. Physical order is independent of
which monitor is primary. To force an external screen to the left of a notebook,
use the following private settings (adjust output names):

```sh
RICE_MONITOR_LAYOUT=ordered
RICE_MONITOR_ORDER='HDMI-1 eDP-1'
RICE_MONITOR_PRIMARY=HDMI-1
```

In ordered mode, these preferences override existing positions and autorandr
profiles. The default preserve mode retains complete active layouts and saved
profiles. Missing preferred outputs are ignored so undocking still works.

 Output names are preferences, not
requirements; native modes are detected at runtime. The local override stays
outside Git. `--adopt-monitor-layout` also leaves existing private overrides alone.

Wallpapers belong in `~/Pictures/wallpapers`, VPN credentials in `~/vpn`, and
engagements in `~/engagements`. These personal files remain outside the
repository. Without a wallpaper, the desktop uses the theme's solid background.

The Burp Suite Professional launcher expects your existing licensed installation
in `~/Burpsuite-Professional`. This repository does not distribute a JAR or license.

## Updates

With a configured remote and upstream branch, run:

```sh
cd ~/rice
./update.sh --dry-run
./update.sh
```

`update.sh` fetches the configured upstream, checks it in a temporary worktree,
runs the test suite, and preflights a three-way merge of installed edits before
advancing the checkout with fast-forward. It deploys regular files with backups
and renders the theme templates. Independent edits are combined; overlapping
edits stop the update before installation, without writing conflict markers to
live configs. Pending checkout edits and divergent Git history need explicit
reconciliation first. See [update details](docs/updating.md).

`./update.sh --no-fetch` uses the already fetched upstream offline.
`./sync.sh` remains the older strict updater, which rejects direct local edits.

The inventory records content fingerprints of installed code and exact upstream
baselines for subsequent merges. A plain `install.sh` deployment
stops before changing files when direct local edits differ from the recorded
version. Reconcile the edits with the checkout first. `--overwrite-local` is an
explicit replacement option that saves the edited files in a new backup; avoid
using it automatically. Changes to `~/rice` need another deployment; changes
to the real files under `~/.config` take effect as applications read/reload them.
New session scripts run at the next login. To reload bspwm explicitly, run
`bspc wm -r`; use `Super+Escape` to reload sxhkd. A running compositor is kept
alive, so its updated configuration takes effect at the next login.

## Optional system integration

SDDM, system editor, power, and performance helpers are installed under
`~/.config/rice/system/`. Review the relevant script before running it
separately with `sudo`. The main dotfile installer does not invoke these helpers,
restart system services, or change boot settings.

A custom login avatar can be placed at `~/.config/rice/login/avatar.png`;
it is excluded from Git. The bundled SilentSDDM sources retain their upstream
documentation, attribution, and licenses in
`stow/desktop/.config/rice/login/silent-rice/`.

## Personal maintenance context

See `AGENTS.md` and `docs/environment-context.md` for the verified notebook
context, all binds, script map, appearance/performance details and the
`linux-debug-wm` skill. Dated snapshots must be refreshed before changes.

## Control center and locking

`Super+Shift+N` opens the control center. Wi-Fi, notification mode, power profiles,
Keep awake, speaker mute and microphone mute update their real and displayed
state together. Power cycling skips profiles the hardware does not offer.
Actions have explicit deadlines, show failures, and restore button interaction.
Bluetooth, Bind saver, VPN, proxy, theme, calendar and mixer open separate tools.
Personal events and custom shortcuts stay outside Git. The hotkey helper also
recovers a missing main sxhkd and serializes reload requests, protecting the
short interval in which sxhkd re-arms its SIGUSR1 handler.

`Super+Shift+X` locks using the prepared dimblur image. The wallpaper helper
prepares that image asynchronously. Locking keeps all monitors active and does
not run image rendering or change RandR geometry. `lock.sh --keep-monitors`
remains accepted for compatibility. Concurrent requests share a lock; if the
themed locker fails, a foreground solid-color i3lock is attempted.

Bluetooth lists paired and nearby devices, confirms forgetting, and stops its
own scan after 20 seconds or when closed. Bind saver captures keys live,
requires SUPER, protects built-in shortcuts, and offers terminal, browser,
workspace, sound, theme, screenshot and session actions. Personal binds are
stored in `~/.config/rice/custom-binds.json` and rendered separately to
`~/.config/sxhkd/custom.sxhkdrc`.

The calendar highlights Today independently of events. Click a day or
Add/manage to create, edit or delete events. Event dots update while the panel
is open. Data stays in `~/.local/share/rice/calendar/events.json`.

## Motion and responsiveness

The launcher detects FT-Labs animation capabilities even for `vgit-*` builds,
uses the modern config for supported official Picom releases, and retains a
compatibility fallback. A warm `motion.py --serve` handles short workspace and
Kitty transitions from memory. It leaves input with the real windows, writes no
screenshots to disk, expires abandoned effects, and cancels before locking.
It sleeps on its socket while idle. Missing compositor/service support falls
back to the original window action.

Existing `Ctrl+Shift+T` and `Ctrl+Shift+Enter` keep their new-tab and split actions.
`Ctrl+Tab` / `Ctrl+Shift+Tab` switch tabs; `Ctrl+Shift+PageDown` / `PageUp`
reorder the active tab with a short transition. Kitty remote control stays off.
Workspace shortcuts, the selector and bar wheel use the same transition path.
The workspace feed for both profiles uses one snapshot per event and keeps its
Python process warm instead of spawning many clients for each redraw.

## Animation settings

Press **Super+A** to open **animation settings**. The same name appears in
shortcuts (`Super+/`). The centered dialog follows the active theme and offers:

- A master switch, VSync, fade controls and a **60 FPS default** frame ceiling.
- Opening, closing and popup effects, enabled individually. FT-Labs exposes its
  supported motion types and spring stiffness, mass, damping and clamping.
  Modern Picom uses native presets and per-event durations.
- Workspace and Kitty transitions with separate switches, styles and durations.
- An unsaved opening preview, quick presets, defaults and undo of the last apply.

Apply preflights a generated config, saves a backup and restarts only the
compositor. Failure restores the previous preferences and compositor settings.
Base Picom files retain their appearance and protected lock/transition rules.
Preferences live in `~/.config/rice/animations.json`; backups are in
`~/.local/state/rice/animation-backups/`. Portable defaults stay in code.

The installed FT-Labs build has no native FPS ceiling. A small local C helper
limits its libepoxy GLX/EGL presentation calls; it is compiled with `cc` in the
user cache and loaded only into Picom. The same ceiling applies to desktop
transition drawing. Turning the frame limit off restores uncapped presentation.
This does not change monitor resolution or refresh, and FPS can be lower than
the ceiling when rendering is slower. No system libraries are replaced.

The compositor starts in its own session, so closing the settings applicator
cannot stop it. The control center checks the actual X11 compositor selection
before creating fullscreen transparent click backdrops. If composition is
unavailable, it opens only the panel and keeps Escape available, avoiding an
opaque black fullscreen window.

Display recovery: if `~/.config/rice/compositor-safe-mode` exists, the launcher
uses the base compatibility config directly, bypasses the FPS helper, and skips
the motion overlay daemon. Applying animation settings is blocked while this
marker exists. It is a private recovery choice, not distributed state. The
2026-11-08 audit found it absent on the notebook, with FT-Labs running; the
earlier black-screen cause remains unproved. Preserve any existing marker on
the destination until its rendering issue has been investigated.
