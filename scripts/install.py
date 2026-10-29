#!/usr/bin/env python3
"""Deploy GNU Stow packages with conflict backups and reversible transactions."""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
PACKAGES = ('desktop', 'shell', 'editor')
INVENTORY = '.local/state/offsec-dotfiles/managed.json'
TEMPLATES = {
    'kitty-colors.conf.tpl': '.config/kitty/current-theme.conf',
    'rofi-colors.rasi.tpl': '.config/rofi/colors.rasi',
    'dunstrc.tpl': '.config/dunst/dunstrc',
    'tint2rc.tpl': '.config/tint2/tint2rc',
    'eww-colors.scss.tpl': '.config/eww/colors.scss',
    'nvim-theme.lua.tpl': '.config/nvim/lua/offsec-theme.lua',
    'gtk-settings.ini.tpl': '.config/gtk-3.0/settings.ini',
    'xsettingsd.conf.tpl': '.config/xsettingsd/xsettingsd.conf',
    'starship.toml.tpl': '.config/starship.toml',
    'betterlockscreenrc.tpl': '.config/betterlockscreenrc',
}


def exists(path):
    return path.exists() or path.is_symlink()


def fingerprint(path):
    if path.is_symlink():
        return {'link': os.readlink(path)}
    if path.is_file():
        return {'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.is_dir():
        return {'directory': True}
    return None


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.offsec-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, indent=2)
            stream.write('\n')
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def sources():
    result = {}
    for package in PACKAGES:
        root = REPO / 'stow' / package
        for path in sorted(root.rglob('*')):
            if path.is_file() and path.name != '.stow-local-ignore':
                rel = str(path.relative_to(root))
                if rel in result:
                    raise RuntimeError(f'Duplicate package target: {rel}')
                result[rel] = path
    return result


def obstructing_parent(target, rel):
    path = target
    for part in Path(rel).parts[:-1]:
        path /= part
        if path.is_symlink() or (exists(path) and not path.is_dir()):
            return str(path.relative_to(target))
    return None


def render(target):
    palette = {}
    for line in (target / '.config/offsec/current-theme.conf').read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            key, value = line.split('=', 1)
            palette[key] = value
            palette[key + '_raw'] = value.removeprefix('#')
    palette['home'] = str(target)
    for template, rel in TEMPLATES.items():
        data = (REPO / 'stow/desktop/.config/offsec/templates' / template).read_text()
        for key, value in palette.items():
            data = data.replace('{{' + key + '}}', value)
        if '{{' in data:
            raise RuntimeError(f'Unresolved template variable in {template}')
        path = target / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)


def restore(backup):
    manifest = backup / 'manifest.json'
    record = json.loads(manifest.read_text())
    if record['status'] == 'restored':
        return
    target = Path(record['target'])
    # Preflight all files before removing anything. Preserve edits made since install.
    for rel, expected in record['after'].items():
        actual = fingerprint(target / rel)
        if actual is not None and actual != expected:
            raise RuntimeError(f'Changed since installation: {target / rel}; backup retained')
    for rel in sorted(record['after'], key=lambda p: len(Path(p).parts), reverse=True):
        path = target / rel
        if path.is_symlink() or path.is_file():
            path.unlink()
    for rel in sorted(record['moved'], key=lambda p: len(Path(p).parts)):
        path = target / rel
        old = backup / 'files' / rel
        if not exists(old):
            continue
        if path.is_dir() and not path.is_symlink():
            # Only directories created around managed files may be removed.
            for root, dirs, files in os.walk(path, topdown=False):
                Path(root).rmdir()
        if exists(path):
            raise RuntimeError(f'Restore conflict: {path}; backup retained')
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(old), path)
    record['status'] = 'restored'
    save(manifest, record)


def deploy(target, dry_run=False):
    links = sources()
    defaults = {str(p.relative_to(REPO / 'defaults')): p
                for p in (REPO / 'defaults').rglob('*') if p.is_file()}
    managed = {**links, **{rel: None for rel in TEMPLATES.values()}}
    managed[INVENTORY] = None
    managed.update({rel: src for rel, src in defaults.items()
                    if obstructing_parent(target, rel) or (target / rel).is_symlink()
                    or not exists(target / rel)})
    preserved_defaults = {rel: (target / rel).read_bytes() for rel in defaults
                          if (target / rel).is_file()}
    backups = set()
    changes = {}
    inventory = target / INVENTORY
    if inventory.is_file() and not obstructing_parent(target, INVENTORY):
        previous = json.loads(inventory.read_text())
        for rel, src in previous.get('links', {}).items():
            if Path(rel).is_absolute() or '..' in Path(rel).parts:
                raise RuntimeError('Invalid path in previous inventory')
            path = target / rel
            if rel not in links and path.is_symlink() and path.resolve() == Path(src).resolve():
                managed[rel] = None
    for rel, src in sorted(managed.items()):
        blocker = obstructing_parent(target, rel)
        path = target / rel
        if not blocker and rel in links and path.is_symlink() and path.resolve() == src:
            continue
        changes[rel] = src
        if blocker:
            backups.add(blocker)
        elif exists(path):
            backups.add(rel)
    backups = {rel for rel in backups if not any(
        parent in backups for parent in map(str, Path(rel).parents) if parent != '.')}
    if dry_run:
        print(json.dumps({'target': str(target), 'backup': sorted(backups),
                          'install': sorted(changes)}, indent=2))
        return
    stow = shutil.which('stow')
    if not stow:
        raise RuntimeError('GNU Stow is required: sudo pacman -S --needed stow')
    backup_root = target / '.local/state/offsec-dotfiles/backups'
    # Do not follow pre-existing symlink parents when storing recovery data.
    if obstructing_parent(target, str(backup_root.relative_to(target)) + '/manifest.json'):
        raise RuntimeError('Backup directory has a symlink/non-directory ancestor')
    backup_root.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'),
                                  dir=backup_root))
    record = {'target': str(target), 'repo': str(REPO), 'status': 'installing',
              'moved': [], 'after': {}}
    manifest = backup / 'manifest.json'
    save(manifest, record)
    deploying = False
    try:
        for rel in sorted(backups):
            old = backup / 'files' / rel
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(target / rel), old)
            record['moved'].append(rel)
            save(manifest, record)
        deploying = True
        subprocess.run([stow, '--dir', str(REPO / 'stow'), '--target', str(target),
                        '--no-folding', '--stow', *PACKAGES], check=True)
        for rel, src in defaults.items():
            path = target / rel
            if not exists(path):
                path.parent.mkdir(parents=True, exist_ok=True)
                if rel in preserved_defaults:
                    path.write_bytes(preserved_defaults[rel])
                else:
                    shutil.copy2(src, path)
        render(target)
        save(target / INVENTORY, {'links': {rel: str(src) for rel, src in links.items()}})
        for rel in changes:
            record['after'][rel] = fingerprint(target / rel)
        record['status'] = 'installed'
        save(manifest, record)
    except BaseException:
        # Stow may have created some links before failing. Remove only our links/files.
        for rel, src in (changes.items() if deploying else ()):
            path = target / rel
            if (rel in links and path.is_symlink() and path.resolve() == src) or (
                    rel not in links and not obstructing_parent(target, rel) and path.is_file()):
                record['after'][rel] = fingerprint(path)
        save(manifest, record)
        restore(backup)
        raise
    command = shlex.join([str(REPO / 'install.sh'), '--restore', str(backup)])
    print(f'Installed: {target}\nBackup: {backup}\nRestore: {command}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', type=Path, default=Path.home())
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--update', action='store_true', help='git pull --ff-only before deployment')
    parser.add_argument('--restore', type=Path)
    args = parser.parse_args()
    target = args.target.expanduser().resolve()
    if not target.is_dir() or target == Path('/') or target.is_relative_to(REPO):
        raise RuntimeError('Target must be an existing home directory outside this repository')
    if args.dry_run and (args.update or args.restore):
        raise RuntimeError('--dry-run cannot be combined with --update/--restore')
    # Serialize per target without writing to the home directory during a dry run.
    with (REPO / '.install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.restore:
            restore(args.restore.expanduser().resolve())
        else:
            if args.update:
                if subprocess.check_output(['git', '-C', str(REPO), 'status', '--porcelain']):
                    raise RuntimeError('Commit/stash local changes before updating')
                subprocess.run(['git', '-C', str(REPO), 'pull', '--ff-only'], check=True)
                # Re-exec the updated installer so new template/package logic is used.
                os.execv(str(REPO / 'install.sh'),
                         [str(REPO / 'install.sh'), '--target', str(target)])
            deploy(target, args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'install: {error}', file=sys.stderr)
        sys.exit(1)
