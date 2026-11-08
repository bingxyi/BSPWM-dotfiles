#!/usr/bin/env python3
"""Deploy editable regular dotfiles with conflict backups and reversible transactions."""

import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
PACKAGES = ("desktop", "shell", "editor")
INVENTORY = ".local/state/rice/managed.json"
PRESERVED = {".config/bspwm/monitors.sh"}
TEMPLATES = {
    "kitty-colors.conf.tpl": ".config/kitty/current-theme.conf",
    "rofi-colors.rasi.tpl": ".config/rofi/colors.rasi",
    "dunstrc.tpl": ".config/dunst/dunstrc",
    "tint2rc.tpl": ".config/tint2/tint2rc",
    "eww-colors.scss.tpl": ".config/eww/colors.scss",
    "nvim-theme.lua.tpl": ".config/nvim/lua/rice-theme.lua",
    "gtk-settings.ini.tpl": ".config/gtk-3.0/settings.ini",
    "xsettingsd.conf.tpl": ".config/xsettingsd/xsettingsd.conf",
    "starship.toml.tpl": ".config/starship.toml",
    "betterlockscreenrc.tpl": ".config/betterlockscreenrc",
}


def exists(path):
    return path.exists() or path.is_symlink()


def fingerprint(path):
    if path.is_symlink():
        return {"link": os.readlink(path)}
    if path.is_file():
        return {"sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    if path.is_dir():
        return {"directory": True}
    return None


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".rice-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, indent=2)
            stream.write("\n")
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def sources(keep_monitors=False):
    result = {}
    for package in PACKAGES:
        root = REPO / "stow" / package
        for path in sorted(root.rglob("*")):
            if "__pycache__" in path.parts or path.suffix in (".pyc", ".pyo"):
                continue
            if path.is_file() and path.name != ".stow-local-ignore":
                rel = str(path.relative_to(root))
                if keep_monitors and rel in PRESERVED:
                    continue
                if rel in result:
                    raise RuntimeError(f"Duplicate package target: {rel}")
                result[rel] = path
    return result


def obstructing_parent(target, rel):
    path = target
    for part in Path(rel).parts[:-1]:
        path /= part
        if path.is_symlink() or (exists(path) and not path.is_dir()):
            return str(path.relative_to(target))
    return None


def render(target, home=None):
    palette = {}
    for line in (target / ".config/rice/current-theme.conf").read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            palette[key] = value
            palette[key + "_raw"] = value.removeprefix("#")
    palette["home"] = str(home if home is not None else target)
    for template, rel in TEMPLATES.items():
        local_template = target / '.config/rice/templates' / template
        source = local_template if local_template.is_file() else REPO / 'stow/desktop/.config/rice/templates' / template
        data = source.read_text()
        for key, value in palette.items():
            data = data.replace("{{" + key + "}}", value)
        if "{{" in data:
            raise RuntimeError(f"Unresolved template variable in {template}")
        path = target / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(data)


def restore(backup):
    manifest = backup / "manifest.json"
    record = json.loads(manifest.read_text())
    if record["status"] == "restored":
        return
    target = Path(record["target"])
    # Preflight all files before removing anything. Preserve edits made since install.
    for rel, expected in record["after"].items():
        actual = fingerprint(target / rel)
        if actual is not None and actual != expected:
            raise RuntimeError(
                f"Changed since installation: {target / rel}; backup retained"
            )
    for rel in sorted(record["after"], key=lambda p: len(Path(p).parts), reverse=True):
        path = target / rel
        if path.is_symlink() or path.is_file():
            path.unlink()
    for rel in sorted(record["moved"], key=lambda p: len(Path(p).parts)):
        path = target / rel
        old = backup / "files" / rel
        if not exists(old):
            continue
        if path.is_dir() and not path.is_symlink():
            # Only directories created around managed files may be removed.
            for root, dirs, files in os.walk(path, topdown=False):
                Path(root).rmdir()
        if exists(path):
            raise RuntimeError(f"Restore conflict: {path}; backup retained")
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(old), path)
    record["status"] = "restored"
    save(manifest, record)


def monitor_preferences(target):
    """Capture preferences, not hardware requirements, without changing X11."""
    if target != Path.home().resolve() or not os.environ.get('DISPLAY'):
        raise RuntimeError('--adopt-monitor-layout requires the current user home and an X11 session')
    layout = subprocess.check_output(['xrandr', '--query'], text=True, timeout=10)
    names = re.findall(r'^(\S+) connected\b', layout, re.M)
    wm = json.loads(subprocess.check_output(['bspc', 'wm', '--dump-state'], text=True, timeout=10))
    primary = next((m['name'] for m in wm['monitors'] if m['name'] in names and
                    any(d['name'] == '1' for d in m['desktops'])), None)
    primary = primary or next(iter(names), None)
    if not primary:
        raise RuntimeError('No connected outputs; monitor preferences were not changed')
    order = [m['name'] for m in wm['monitors'] if m['name'] in names]
    return ('# Private preferences captured at installation; disconnected outputs are optional.\n'
            f'RICE_MONITOR_PRIMARY={shlex.quote(primary)}\n'
            f'RICE_MONITOR_ORDER={shlex.quote(" ".join(order))}\n')


def check_dependencies():
    required = ('bash', 'bspwm', 'bspc', 'sxhkd', 'xrandr', 'picom',
                'rofi', 'kitty', 'fish', 'cc', 'jq', 'dunst', 'zsh', 'nvim', 'xsettingsd', 'flock', 'xinput')
    missing = [command for command in required if not shutil.which(command)]
    if not shutil.which('tint2') and not shutil.which('eww'):
        missing.append('tint2 or eww')
    try:
        import gi
        import cairo
        gi.require_version('Gtk', '3.0')
        gi.require_version('GdkX11', '3.0')
        from gi.repository import Gtk, GdkX11, Gio
    except (ImportError, ValueError):
        missing.append('python-gobject, python-cairo and gtk3 (desktop dialogs/transitions)')
    if missing:
        raise RuntimeError('Missing session dependencies (no files changed): ' + ', '.join(missing))


def deploy(target, dry_run=False, keep_monitors=False, adopt_monitor_layout=False,
           overwrite_local=False):
    """Deploy independent regular files; retain local edits unless explicitly replaced."""
    selected = sources(keep_monitors)
    preserved = PRESERVED if keep_monitors else set()
    inventory = target / INVENTORY
    if obstructing_parent(target, INVENTORY):
        raise RuntimeError('Inventory has a symlink/non-directory ancestor; no files changed')
    previous = json.loads(inventory.read_text()) if inventory.is_file() else {}
    # Shared configuration directories are not replaced or traversed through links.
    for rel in [*selected, *TEMPLATES.values()]:
        if obstructing_parent(target, rel):
            raise RuntimeError(f'Symlink/non-directory ancestor of {target / rel}; no files changed')
    conflicts = []
    for rel, expected in previous.get('files', {}).items():
        if Path(rel).is_absolute() or '..' in Path(rel).parts:
            raise RuntimeError('Invalid path in previous inventory')
        if rel in selected and exists(target / rel):
            current = fingerprint(target / rel)
            if current != expected and current != fingerprint(selected[rel]):
                conflicts.append(rel)
    if conflicts and not overwrite_local:
        raise RuntimeError('Local edits retained; no files changed: ' + ', '.join(conflicts) +
                           '. Reconcile them with ~/rice, or use --overwrite-local to replace with backup.')
    generated = {}
    local = target / '.config/bspwm/local.sh'
    if local.is_file() and not local.is_symlink():
        data = local.read_text()
        migrated = data.replace('$HOME/.config/offsec/bin', '$HOME/.config/rice/bin')
        if not keep_monitors:
            migrated = migrated.replace('    autorandr --change --default default 2>/dev/null &',
                                        '    : # Layouts are managed by rice monitors.sh')
        if migrated != data:
            generated['.config/bspwm/local.sh'] = (migrated, local.stat().st_mode & 0o777)
    preferences = '.config/bspwm/monitors.local.sh'
    if adopt_monitor_layout and not exists(target / preferences):
        generated[preferences] = (monitor_preferences(target), 0o644)
    defaults = {str(p.relative_to(REPO / 'defaults')): p
                for p in (REPO / 'defaults').rglob('*') if p.is_file()}
    for rel in [*defaults, *generated]:
        if obstructing_parent(target, rel):
            raise RuntimeError(f'Symlink/non-directory ancestor of {target / rel}; no files changed')
    # Render in isolation before moving any live file, so bad templates cannot
    # leave a partially configured session. Personal template edits are protected
    # by the same conflict detection as scripts and other static sources.
    with tempfile.TemporaryDirectory(prefix='rice-deploy-') as directory:
        stage = Path(directory)
        desired = {}
        for rel, source in selected.items():
            path = stage / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, path)
            desired[rel] = path
        for rel, source in defaults.items():
            path = stage / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if (target / rel).is_file():
                shutil.copy2(target / rel, path)
            else:
                shutil.copy2(source, path)
            # Existing regular mutable defaults remain entirely unmanaged.
            if not (target / rel).is_file() or (target / rel).is_symlink():
                desired[rel] = path
        for rel, (data, mode) in generated.items():
            path = stage / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data)
            path.chmod(mode)
            desired[rel] = path
        render(stage, home=target)
        desired.update({rel: stage / rel for rel in TEMPLATES.values()})
        state = {'schema': 2, 'mode': 'copy',
                 'files': {rel: fingerprint(stage / rel) for rel in selected},
                 'sources': {rel: str(src) for rel, src in selected.items()}}
        save(stage / INVENTORY, state)
        desired[INVENTORY] = stage / INVENTORY
        retained_removed = []
        old = {**previous.get('links', {}), **previous.get('files', {})}
        for rel, expected in old.items():
            if Path(rel).is_absolute() or '..' in Path(rel).parts:
                raise RuntimeError('Invalid path in previous inventory')
            if rel in desired or rel in preserved:
                continue
            path = target / rel
            if not exists(path):
                continue
            if obstructing_parent(target, rel):
                raise RuntimeError(f'Symlink ancestor of previous managed file {path}')
            unchanged = (path.is_symlink() and isinstance(expected, str) and
                         path.resolve() == Path(expected).resolve()) or (
                             isinstance(expected, dict) and fingerprint(path) == expected)
            if unchanged:
                desired[rel] = None
            else:
                retained_removed.append(rel)
        changes = {rel: src for rel, src in desired.items()
                   if src is None or (target / rel).is_symlink() or
                   fingerprint(target / rel) != fingerprint(src) or
                   ((target / rel).is_file() and
                    (target / rel).stat().st_mode & 0o777 != src.stat().st_mode & 0o777)}
        backups = [rel for rel in changes if exists(target / rel)]
        if dry_run:
            print(json.dumps({'target': str(target), 'mode': 'copy', 'backup': sorted(backups),
                              'install': sorted(changes), 'preserve': sorted(preserved),
                              'migrate': sorted(generated), 'local_conflicts': conflicts,
                              'retained_removed_local_files': retained_removed}, indent=2))
            return
        backup_root = target / '.local/state/rice/backups'
        if obstructing_parent(target, str(backup_root.relative_to(target)) + '/manifest.json'):
            raise RuntimeError('Backup directory has a symlink/non-directory ancestor')
        backup_root.mkdir(parents=True, exist_ok=True)
        backup = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'),
                                      dir=backup_root))
        record = {'target': str(target), 'repo': str(REPO), 'mode': 'copy',
                  'status': 'installing', 'moved': [], 'after': {}}
        manifest = backup / 'manifest.json'
        save(manifest, record)
        written = set()
        try:
            for rel in sorted(backups):
                path = target / rel
                # Preserve materialized content too: a saved symlink alone is
                # insufficient if the checkout is later moved or edited.
                if path.is_symlink() and path.is_file():
                    resolved = backup / 'resolved' / rel
                    resolved.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, resolved)
                old_path = backup / 'files' / rel
                old_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(path), old_path)
                record['moved'].append(rel)
                save(manifest, record)
            for rel, src in changes.items():
                path = target / rel
                if src is not None:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    fd, temp = tempfile.mkstemp(prefix='.rice-copy-', dir=path.parent)
                    os.close(fd)
                    try:
                        shutil.copy2(src, temp)
                        os.replace(temp, path)
                    finally:
                        Path(temp).unlink(missing_ok=True)
                written.add(rel)
                record['after'][rel] = fingerprint(path)
                save(manifest, record)
            record['status'] = 'installed'
            save(manifest, record)
        except BaseException:
            for rel in written:
                record['after'][rel] = fingerprint(target / rel)
            save(manifest, record)
            restore(backup)
            raise
        command = shlex.join([str(REPO / 'install.sh'), '--restore', str(backup)])
        print(f'Installed regular files: {target}\nBackup: {backup}\nRestore: {command}')
        if retained_removed:
            print('Retained personal files removed upstream: ' + ', '.join(retained_removed))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=Path, default=Path.home())
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument('--keep-monitors', action='store_true', help='keep a personal monitors.sh instead of installing the automatic controller')
    parser.add_argument('--adopt-monitor-layout', action='store_true', help='retain the current workspace/bar monitor preference in a private local file')
    parser.add_argument(
        "--update", action="store_true", help="git pull --ff-only before deployment"
    )
    parser.add_argument("--restore", type=Path)
    parser.add_argument('--overwrite-local', action='store_true', help='replace edited installed code with repository files, preserving a backup')
    args = parser.parse_args()
    target = args.target.expanduser().resolve()
    if not target.is_dir() or target == Path("/") or target.is_relative_to(REPO):
        raise RuntimeError(
            "Target must be an existing home directory outside this repository"
        )
    if args.dry_run and (args.update or args.restore):
        raise RuntimeError("--dry-run cannot be combined with --update/--restore")
    if args.keep_monitors and args.adopt_monitor_layout:
        raise RuntimeError('--keep-monitors cannot be combined with --adopt-monitor-layout')
    # Serialize per target without writing to the home directory during a dry run.
    with (REPO / ".install.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.restore:
            restore(args.restore.expanduser().resolve())
        else:
            if args.update:
                if subprocess.check_output(
                    ["git", "-C", str(REPO), "status", "--porcelain"]
                ):
                    raise RuntimeError("Commit/stash local changes before updating")
                subprocess.run(
                    ["git", "-C", str(REPO), "pull", "--ff-only"], check=True
                )
                # Re-exec the updated installer so new template/package logic is used.
                extra = (['--overwrite-local'] if args.overwrite_local else []) + (['--keep-monitors'] if args.keep_monitors else []) + (['--adopt-monitor-layout'] if args.adopt_monitor_layout else [])
                os.execv(
                    str(REPO / "install.sh"),
                    [str(REPO / "install.sh"), "--target", str(target), *extra],
                )
            if target == Path.home().resolve() and not args.dry_run:
                check_dependencies()
            deploy(target, args.dry_run, args.keep_monitors, args.adopt_monitor_layout, args.overwrite_local)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"install: {error}", file=sys.stderr)
        sys.exit(1)
