#!/usr/bin/env python3
"""Read-only syntax, keybinding, path, template and secret checks."""
import ast
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'scripts'))
import install


def expand(text):
    match = re.search(r'\{([^{}]*)\}', text)
    if not match:
        return [text]
    return [item for value in match[1].split(',') for item in expand(
        text[:match.start()] + value + text[match.end():])]


def main():
    errors = []
    shell = []
    files = [path for root in ('stow', 'defaults', 'scripts', 'tests', 'examples')
             for path in (REPO / root).rglob('*') if path.is_file()]
    files += [REPO / 'install.sh', REPO / 'sync.sh']
    for path in files:
        if path.suffix == '.py':
            try:
                ast.parse(path.read_text(), str(path))
            except SyntaxError as error:
                errors.append(str(error))
        if path.suffix == '.lua' and shutil.which('luac'):
            result = subprocess.run(['luac', '-p', str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr)
        if path.suffix == '.sh' or path.name in ('bspwmrc', '.xinitrc', '.xprofile', '.profile',
                                                'rice-powerprofile', 'sddm-Xsetup', 'burpsuite-pro'):
            shell.append(str(path))
            result = subprocess.run(['bash', '-n', str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr)
        elif path.name in ('.zshrc', '.zprofile'):
            result = subprocess.run(['zsh', '-n', str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr)
        if path.name == 'bspwmrc' and not os.access(path, os.X_OK):
            errors.append(f'Not executable: {path}')
        if path.suffix in ('.sh', '.py', '.tpl', '.yuck', '.desktop') or path.name.startswith('.z'):
            for line in path.read_text().splitlines():
                if '/home/bingxyi/' in line and path.is_relative_to(REPO / 'stow'):
                    errors.append(f'Hardcoded home: {path}')
                if re.search(r'-----BEGIN (?:OPENSSH |RSA |EC |DSA )?PRIVATE KEY-----|\bAKIA[0-9A-Z]{16}\b|\bgh[pousr]_[A-Za-z0-9]{30,}', line):
                    errors.append(f'Potential secret: {path}')
    seen = {}
    config = REPO / 'stow/desktop/.config/sxhkd/sxhkdrc'
    for number, line in enumerate(config.read_text().splitlines(), 1):
        if line and not line[0].isspace() and not line.startswith('#'):
            for chord in expand(line):
                key = tuple(sorted(part.strip() for part in chord.split('+')))
                if key in seen:
                    errors.append(f'Duplicate hotkey: lines {seen[key]}, {number}: {chord}')
                seen[key] = number
        for rel in re.findall(r'~/([^\s;]+)', line):
            if rel.startswith('.config/rice/bin/'):
                path = REPO / 'stow/desktop' / rel
                if not path.is_file() or not os.access(path, os.X_OK):
                    errors.append(f'Missing/non-executable hotkey script: {rel}')
    with tempfile.TemporaryDirectory(prefix='rice-render-', dir='/tmp') as directory:
        target = Path(directory)
        shutil.copytree(REPO / 'defaults', target, dirs_exist_ok=True)
        install.render(target)
        for rel in install.TEMPLATES.values():
            if '{{' in (target / rel).read_text():
                errors.append(f'Unresolved template: {rel}')
    if shutil.which('shellcheck'):
        result = subprocess.run(['shellcheck', '-S', 'warning', '-e', 'SC1090,SC1091', *shell],
                                capture_output=True, text=True)
        if result.returncode:
            errors.append(result.stdout + result.stderr)
    else:
        print('SKIP shellcheck: executable unavailable')
    if not shutil.which('luac'):
        print('SKIP Lua syntax: luac unavailable')
    print(f'Checked {len(shell)} shell files, {len(seen)} hotkeys and {len(install.TEMPLATES)} templates')
    for error in errors:
        print(error, file=sys.stderr)
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
