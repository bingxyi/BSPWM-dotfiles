#!/usr/bin/env python3
"""Validate incoming Git changes and merge installed local dotfile edits."""
import argparse
import fcntl
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]


def git(*args, capture=False):
    result = subprocess.run(['git', '-C', str(REPO), *args], check=True,
                            text=True, stdout=subprocess.PIPE if capture else None)
    return result.stdout.strip() if capture else None


def load_installer(repo):
    spec = importlib.util.spec_from_file_location('rice_incoming_install', repo / 'scripts/install.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run(args):
    target = args.target.expanduser().resolve()
    if not target.is_dir() or target == Path('/') or target.is_relative_to(REPO):
        raise RuntimeError('Target must be an existing home outside the checkout')
    with (REPO / '.install.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if git('status', '--porcelain', capture=True):
            raise RuntimeError('Checkout has local changes; preserve/commit them before updating. No automatic stash/reset.')
        head = git('rev-parse', 'HEAD', capture=True)
        branch = git('symbolic-ref', '--short', 'HEAD', capture=True)
        upstream = git('rev-parse', '--symbolic-full-name', '@{upstream}', capture=True)
        remote = git('config', '--get', f'branch.{branch}.remote', capture=True)
        if not args.no_fetch:
            git('fetch', '--', remote)
        revision = git('rev-parse', upstream, capture=True)
        ancestor = subprocess.run(['git', '-C', str(REPO), 'merge-base', '--is-ancestor', head, revision])
        if ancestor.returncode:
            raise RuntimeError('Local branch has commits outside upstream; reconcile Git history first. No files installed.')
        with tempfile.TemporaryDirectory(prefix='rice-update-') as directory:
            candidate = Path(directory) / 'incoming'
            git('worktree', 'add', '--detach', str(candidate), revision)
            try:
                # Execute checks in the actual incoming tree, without importing plugins or using X11.
                subprocess.run([sys.executable, '-B', str(candidate / 'scripts/check.py')], check=True)
                subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests'],
                               cwd=candidate, check=True)
                installer = load_installer(candidate)
                if target == Path.home().resolve():
                    installer.check_dependencies()
                installer.deploy(target, dry_run=True, keep_monitors=args.keep_monitors, merge_local=True)
                if args.dry_run:
                    print(f'Preview complete: {head[:12]} -> {revision[:12]}; checkout and installed files retained.')
                    return
                if git('rev-parse', 'HEAD', capture=True) != head or git('status', '--porcelain', capture=True):
                    raise RuntimeError('Checkout changed during validation; retry after reconciliation')
            finally:
                git('worktree', 'remove', '--force', str(candidate))
        git('merge', '--ff-only', revision)
        # Release the lock on exec; the current installer acquires the same lock
        # and repeats preflight against live files (including changes made while testing).
        argv = [str(REPO / 'install.sh'), '--merge-local', '--target', str(target)]
        if args.keep_monitors:
            argv.append('--keep-monitors')
        os.execv(argv[0], argv)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dry-run', action='store_true', help='fetch, validate and preview without installing or advancing checkout')
    parser.add_argument('--no-fetch', action='store_true', help='use the already fetched upstream (offline)')
    parser.add_argument('--target', type=Path, default=Path.home(), help='existing destination HOME')
    parser.add_argument('--keep-monitors', action='store_true', help='retain a custom monitors.sh')
    run(parser.parse_args())


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'update: {error}', file=sys.stderr)
        sys.exit(1)
