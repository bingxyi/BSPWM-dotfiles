#!/usr/bin/env python3
"""Install the reviewed local SilentSDDM palette bridge without restarting SDDM."""
import configparser
from datetime import datetime
import os
from pathlib import Path
import pwd
import shutil

if os.geteuid() != 0:
    raise SystemExit('Run with pkexec or sudo; no display-manager restart is needed.')

user = pwd.getpwnam(os.environ['SUDO_USER'])
source = Path(user.pw_dir) / '.config/rice/login'
base = Path('/usr/share/sddm/themes/silent')
target = Path('/usr/share/sddm/themes/silent-rice')
public = Path('/var/lib') / ('rice-login-' + user.pw_name)
override = Path('/etc/sddm.conf.d/90-rice-login.conf')
face = Path('/usr/share/sddm/faces') / (user.pw_name + '.face.icon')
data = (source / 'silent-rice/configs/rice.conf').read_bytes()
cfg = configparser.ConfigParser(interpolation=None)
cfg.read_string(data.decode())
assert cfg['LoginScreen']['background-color'].startswith('#')
avatar = source / 'avatar.png'
if avatar.exists():
    assert avatar.read_bytes().startswith(b'\x89PNG\r\n\x1a\n')
assert base.is_dir() and not target.exists(), 'Existing target: inspect before reinstalling'

backup = Path('/var/lib/sddm') / ('rice-login-backup-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
backup.mkdir(mode=0o700)
for path in (override, face):
    if path.exists():
        shutil.copy2(path, backup / path.name)
# Recovery only removes the new drop-in/theme; the original Silent theme stays intact.
rollback = ['#!/usr/bin/env bash', 'set -eu']
for path in (override, face):
    old = backup / path.name
    rollback.append(f'cp -- {old} {path}' if old.exists() else f'rm -f -- {path}')
rollback += [f'rm -rf -- {target}', '# No restart: takes effect on the next normal login.']
(backup / 'rollback.sh').write_text('\n'.join(rollback) + '\n')
(backup / 'rollback.sh').chmod(0o700)

shutil.copytree(base, target)
metadata = target / 'metadata.desktop'
metadata.write_text(metadata.read_text().replace('ConfigFile=configs/catppuccin-mocha.conf',
                                               'ConfigFile=configs/rice.conf', 1))
public.mkdir(mode=0o755, exist_ok=True)
os.chown(public, user.pw_uid, user.pw_gid)
os.chmod(public, 0o755)
(public / 'theme.conf').write_bytes(data)
os.chown(public / 'theme.conf', user.pw_uid, user.pw_gid)
os.chmod(public / 'theme.conf', 0o644)
(target / 'configs/rice.conf').symlink_to(public / 'theme.conf')
(target / 'backgrounds/rice-wallpaper.png').symlink_to(public / 'wallpaper.png')
wallpaper = source / 'silent-rice/backgrounds/rice-wallpaper.png'
if wallpaper.exists():
    shutil.copyfile(wallpaper, public / 'wallpaper.png')
    os.chown(public / 'wallpaper.png', user.pw_uid, user.pw_gid)
    os.chmod(public / 'wallpaper.png', 0o644)
if avatar.exists():
    shutil.copyfile(avatar, face)
    os.chmod(face, 0o644)
override.write_text('[Theme]\nCurrent=silent-rice\nEnableAvatars=true\n\n[General]\n'
                    'GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent-rice/components/,QT_IM_MODULE=qtvirtualkeyboard\n')
os.chmod(override, 0o644)
print(f'Installed login avatar and palette bridge. Recovery: {backup}/rollback.sh')
