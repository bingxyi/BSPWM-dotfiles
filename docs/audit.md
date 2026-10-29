# BSPWM-dotfiles audit · 2026-10-29

This document records the original implementation audit. The evidence and
environment limitations below describe that audit run, rather than a guarantee
about every host where this rice may be installed.

## Fixes in the tracked configuration

- Zsh: `cde` uses `engagement_path` without changing the special `path`/`PATH`
  variable, creates the cache before `compinit`, uses `$HOME`, and handles a
  missing local bootstrap.
- sxhkd: the emoji picker uses `Super+Alt+Period`, avoiding the monitor-switching
  shortcuts.
- Monitors: autodetection selects distinct outputs from a single RandR snapshot,
  uses native modes and vertical centering, restores normal rotation for a single
  display, and falls back without disabling other outputs. Local overrides remain
  outside Git.
- Startup: waits for actual bspwm monitor rectangles after RandR before assigning
  desktops, and creates the log directory before starting the mouse watcher.
- Bar/compositor: serializes concurrent starts with locks, makes `--start`
  idempotent, checks readiness with `eww ping`, and preserves a running picom.
  Initial tint2 generation uses `--render-only` to avoid recursively restarting
  the bar.
- Lock screen: the i3lock fallback receives a hexadecimal color without `#`.
- Themes: locks theme application, uses unique temporary files, propagates errors,
  and supports rendering without graphical services. tint2 templates use
  `{{home}}`; the media backend returns a placeholder relative to the current user.
- Shell: avoids `basename` subprocesses during frequent initialization, reads
  state and palettes with builtins, removes repeated desktop-selector queries and
  an unused dependency variable, and prevents repeated PATH growth.
- Installer: disables Stow directory folding, backs up conflicts and broken links,
  protects symlinked ancestor directories, rolls back failed transactions, tracks
  managed links to remove deleted sources, preserves mutable state, and refuses
  to restore over later edits.
- Optional system scripts: resolve the target user dynamically and parameterize
  sudoers. The main system helper installer creates backups and a restore script.

## Original local evidence

- `python3 scripts/check.py`: checked syntax for 57 shell files, Lua/Python files,
  117 distinct key combinations, shortcut script paths, bspwmrc permissions, ten
  templates, and local secret patterns.
- `python3 -m unittest discover -s tests -v`: ran 16 tests; 15 passed and one was
  skipped because GNU Stow was unavailable. Transaction unit tests use a Stow
  adapter; the separate integration test requires the real executable.
- Regression checks used temporary homes to exercise valid engagement paths,
  stable PATH values, distinct dual-monitor fallbacks, centering, single-display
  mode, invalid modes, concurrent bar startup, i3lock colors, and rendering
  without X11. External services and RandR were mocked in those tests.
- `.gitignore` was checked against `.env`, keys, AWS credentials, history, swap
  files, temporary files, and the login avatar. Public `offsec/env` and defaults
  remain tracked.
- `install.sh --dry-run` produced a plan for the current home without modifying it.

## Original environment limitations

- X11 and the bspwm socket were inaccessible in the sandbox, so the audit did
  not visually validate the compositor, struts, windows, hotkeys, or actual
  monitor switching.
- GNU Stow and ShellCheck were unavailable. Installing them with
  `sudo -n pacman -S ...` required a password, and an unprivileged download failed
  because DNS resolution was unavailable. Real Stow integration, ShellCheck,
  and deployment to the home directory remained pending. Elevated execution was
  also rejected by sandbox policy (`sandbox_approval: false`); active dotfiles in
  the original home did not receive those fixes.
- Automatic approval review rejected the original Aikido submission because it
  involved private local code and an external service without specific
  authorization. No Aikido result was used as evidence. The local checks do not
  constitute a complete security audit.
- `pacman -Qdtq` reported `go`, `python-build`, `python-installer`,
  `qemu-system-aarch64`, and `sassc`. These were orphan candidates according to
  pacman's database, which does not prove they were unused. No packages were
  removed; Go, QEMU, and Sass may still be used outside package dependencies.

## Host activation and verification

```sh
cd ~/BSPWM-dotfiles
sudo pacman -S --needed stow shellcheck
python3 scripts/check.py
python3 -m unittest discover -s tests -v
./install.sh --dry-run
./install.sh
systemctl --user daemon-reload
systemctl --user enable --now offsec-notification-retention.service
# Review the backup and finish work affected by layout changes before reloading.
bspc wm -r
# Super+Escape reloads sxhkd.
bspc query -M --names
bspc wm --dump-state
xrandr --query
```

The installer prints the backup path and the exact restore command. Its internal
state directory remains `~/.local/state/offsec-dotfiles/` for compatibility.
