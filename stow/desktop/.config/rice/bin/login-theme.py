#!/usr/bin/env python3
"""Render SilentSDDM from the same palette as the desktop; publish data only."""
import argparse
import configparser
import os
from pathlib import Path
import re
import pwd
import shutil
import subprocess
import tempfile

ROOT = Path.home() / '.config/rice'
STATE = Path.home() / '.local/share/rice'
STAGE = ROOT / 'login/silent-rice'
PUBLIC = Path('/var/lib') / ('rice-login-' + pwd.getpwuid(os.getuid()).pw_name)
STYLES = {'minimal': 'Minimal · centered', 'left': 'Editorial · left aligned',
          'wallpaper': 'Wallpaper · centered'}


def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.login-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as out:
            out.write(data)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        Path(tmp).unlink(missing_ok=True)


def palette(path):
    values = dict(line.split('=', 1) for line in path.read_text().splitlines()
                  if '=' in line and not line.startswith('#'))
    for key in ('bg', 'bg_alt', 'surface', 'overlay', 'fg', 'fg_dim', 'accent',
                'accent_alt', 'urgent', 'bg_dim'):
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', values[key]):
            raise ValueError(f'Invalid palette color: {key}')
    return values


def render(values, style):
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read(STAGE / 'configs/catppuccin-mocha.conf')
    colors = {'#1e1e2e': values['bg'], '#181825': values['bg_alt'],
              '#11111b': values['bg_dim'], '#313244': values['surface'],
              '#45475a': values['overlay'], '#cdd6f4': values['fg'],
              '#a6adc8': values['fg_dim'], '#89dceb': values['accent'],
              '#74c7ec': values['accent_alt'], '#f38ba8': values['urgent'],
              '#f9e2af': values['yellow']}
    for section in cfg:
        for key, value in list(cfg[section].items()):
            if value.strip('"').lower() in colors:
                cfg[section][key] = colors[value.strip('"').lower()]
    def setv(section, **values):
        for key, value in values.items():
            cfg[section][key.replace('_', '-')] = str(value)
    for section in ('LockScreen', 'LoginScreen'):
        setv(section, background='rice-wallpaper.png' if style == 'wallpaper' else '',
             use_background_color='false' if style == 'wallpaper' else 'true',
             background_color=values['bg'], brightness=0,
             blur=12 if style == 'wallpaper' else 0)
    setv('LockScreen.Date', locale='en_US')
    setv('LockScreen.Message', icon='enter.svg', paint_icon='true', color=values['fg_dim'])
    setv('LoginScreen.LoginArea', position='left' if style == 'left' else 'center',
         margin=160 if style == 'left' else -1)
    setv('LoginScreen.LoginArea.Avatar', active_border_size=2,
         active_border_color=values['accent'], active_size=128)
    setv('LoginScreen.LoginArea.PasswordInput', width=260, height=40,
         border_size=1, border_color=values['overlay'])
    setv('LoginScreen.LoginArea.LoginButton', background_color=values['accent'],
         content_color=values['bg_dim'], active_background_color=values['accent_alt'],
         active_content_color=values['bg_dim'])
    import io
    out = io.StringIO()
    cfg.write(out)
    return out.getvalue().encode()


def sync(style=None):
    style_file = STATE / 'login-style'
    style = style or (style_file.read_text().strip() if style_file.exists() else 'minimal')
    if style not in STYLES:
        raise ValueError('Unknown login style')
    values = palette(ROOT / 'current-theme.conf')
    data = render(values, style)
    if not (STAGE / 'configs/catppuccin-mocha.conf').is_file():
        raise FileNotFoundError('Missing SilentSDDM theme sources')
    atomic(STAGE / 'configs/rice.conf', data)
    wallpaper = Path.home() / 'Pictures/wallpapers' / values['wallpaper']
    if style == 'wallpaper':
        if not wallpaper.is_file():
            raise FileNotFoundError(wallpaper)
        # Source is an existing wallpaper; no dependency on private home at login.
        shutil.copyfile(wallpaper, STAGE / 'backgrounds/rice-wallpaper.png')
    if PUBLIC.is_dir() and os.access(PUBLIC, os.W_OK):
        if style == 'wallpaper':
            atomic(PUBLIC / 'wallpaper.png', wallpaper.read_bytes())
        atomic(PUBLIC / 'theme.conf', data)
    atomic(style_file, style.encode())
    print(f"Login: {STYLES[style]} · {values['name']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--style', choices=STYLES)
    parser.add_argument('--sync', action='store_true')
    parser.add_argument('--menu', action='store_true')
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    style = args.style
    if args.menu:
        choice = subprocess.run(['rofi', '-dmenu', '-i', '-p', 'login style', '-theme',
                                 str(Path.home() / '.config/rofi/themes/menu.rasi')],
                                input='\n'.join(STYLES.values()), text=True,
                                capture_output=True)
        if choice.returncode:
            return
        style = next((k for k, v in STYLES.items() if v == choice.stdout.strip()), None)
        if not style:
            return
    sync(style)
    if args.preview:
        env = dict(os.environ, QT_IM_MODULE='qtvirtualkeyboard',
                   QML2_IMPORT_PATH=str(STAGE / 'components'))
        subprocess.run(['sddm-greeter-qt6', '--test-mode', '--theme', str(STAGE)], env=env,
                       check=True)


if __name__ == '__main__':
    main()
