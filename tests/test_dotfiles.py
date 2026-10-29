"""Regressions use temporary homes and stubbed external services, never live X11."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer', ROOT / 'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class RegressionTests(unittest.TestCase):
    def test_cde_with_valid_engagement(self):
        source = (ROOT / 'stow/shell/.zshrc').read_text()
        function = source[source.index('function cde()'):source.index('# $TARGET')]
        with tempfile.TemporaryDirectory(prefix='rice-engagement-') as directory:
            state = Path(directory) / 'rice'
            state.mkdir()
            (state / 'engagement').write_text(directory)
            result = subprocess.run(['zsh', '-f', '-c', function + '\ncde && pwd'],
                                    env={**os.environ, 'XDG_DATA_HOME': directory},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), directory)

    def monitor_commands(self, query, extra_env=None, fail_first=False):
        with tempfile.TemporaryDirectory(prefix='rice-monitors-') as directory:
            root = Path(directory)
            (root / 'query').write_text(query)
            stub = root / 'xrandr'
            stub.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ['FIXTURE'])
if sys.argv[1:] == ['--query']:
    print((root / 'query').read_text()); sys.exit(0)
with (root / 'calls').open('a') as out: out.write(json.dumps(sys.argv[1:])+'\\n')
if os.environ.get('FAIL_FIRST') and not (root/'failed').exists():
    (root/'failed').touch();sys.exit(1)
''')
            stub.chmod(0o755)
            env = {**os.environ, 'HOME': directory, 'FIXTURE': directory,
                   'PATH': directory + ':' + os.environ['PATH']}
            for name in ('MON_H', 'MON_V', 'MODE_H', 'MODE_V', 'RATE_H', 'RATE_V'):
                env.pop(name, None)
            env.update(extra_env or {})
            if fail_first:
                env['FAIL_FIRST'] = '1'
            result = subprocess.run(['bash', str(ROOT / 'stow/desktop/.config/bspwm/monitors.sh')],
                                    env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return [json.loads(line) for line in (root / 'calls').read_text().splitlines()]

    def test_monitor_alias_fallback_is_distinct_and_centered(self):
        calls = self.monitor_commands('DVI-D-0 connected\n   1920x1080 60.0*+\nDP-1 connected\n   1920x1080 60.0+\n')
        call = calls[0]
        names = [call[i+1] for i, token in enumerate(call) if token == '--output']
        positions = [call[i+1] for i, token in enumerate(call) if token == '--pos']
        self.assertEqual(names, ['DVI-D-0', 'DP-1'])
        self.assertEqual(positions, ['1080x420', '0x0'])

    def test_single_monitor_clears_portrait_rotation(self):
        call = self.monitor_commands('eDP-1 connected\n   2560x1600 60.0*+\n')[0]
        self.assertEqual(call.count('--output'), 1)
        self.assertIn('normal', call)
        self.assertEqual(call[call.index('--pos')+1], '0x0')

    def test_unsupported_explicit_mode_falls_back_without_disabling_outputs(self):
        calls = self.monitor_commands('eDP-1 connected\n   2560x1600 60.0*+\n',
                                      {'MODE_H': '1920x1080', 'RATE_H': '75'}, True)
        self.assertIn('--auto', calls[-1])
        self.assertTrue(all('--off' not in call for call in calls))

    def test_shell_environment_is_idempotent(self):
        envfile = ROOT / 'stow/desktop/.config/rice/env'
        command = '. "$1"; first=$PATH; . "$1"; [[ "$first" == "$PATH" ]]'
        result = subprocess.run(['bash', '-c', command, 'bash', str(envfile)])
        self.assertEqual(result.returncode, 0)

    def shell_home(self, directory):
        home = Path(directory)
        source = ROOT / 'stow/desktop/.config/rice'
        shutil.copytree(source / 'bin', home / '.config/rice/bin')
        shutil.copytree(ROOT / 'defaults', home, dirs_exist_ok=True)
        return {**os.environ, 'HOME': directory, 'XDG_RUNTIME_DIR': directory,
                'XDG_DATA_HOME': str(home / '.local/share')}

    def test_concurrent_bar_start_is_singleton(self):
        with tempfile.TemporaryDirectory(prefix='rice-bar-') as directory:
            env = self.shell_home(directory)
            script = '''. "$HOME/.config/rice/bin/bar.sh"
pgrep() { [[ -e "$HOME/started" ]]; }
eww() { return 1; }
start_bar() { sleep 0.05; touch "$HOME/started"; printf 'start\\n' >> "$HOME/count"; }
main --start
'''
            processes = [subprocess.Popen(['bash', '-c', script], env=env) for _ in range(2)]
            for process in processes:
                self.assertEqual(process.wait(timeout=5), 0)
            self.assertEqual((Path(directory) / 'count').read_text().splitlines(), ['start'])

    def test_i3lock_fallback_uses_hex_without_hash(self):
        with tempfile.TemporaryDirectory(prefix='rice-lock-') as directory:
            env = self.shell_home(directory)
            (Path(directory) / '.config/rice/current-theme.conf').write_text('bg=#1e1e2e\n')
            script = '''. "$HOME/.config/rice/bin/lock.sh"
command() { [[ "$2" != betterlockscreen ]]; }
i3lock() { printf '%s\\n' "$*"; }
do_lock
'''
            result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), '-c 1e1e2e --nofork')

    def test_render_only_generates_portable_files_without_x11(self):
        with tempfile.TemporaryDirectory(prefix='rice-render-') as directory:
            env = self.shell_home(directory)
            home = Path(directory)
            shutil.copytree(ROOT / 'stow/desktop/.config/rice/templates',
                            home / '.config/rice/templates')
            shutil.copytree(ROOT / 'stow/desktop/.config/rice/themes',
                            home / '.config/rice/themes')
            env.pop('DISPLAY', None)
            result = subprocess.run(['bash', str(home / '.config/rice/bin/theme.sh'),
                                     '--render-only', '--apply', 'catppuccin-mocha'],
                                    env=env, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            self.assertIn(directory, (home / '.config/tint2/tint2rc').read_text())


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rice install ')
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo with spaces'
        self.target = self.base / 'home with spaces'
        self.target.mkdir()
        for name in installer.PACKAGES:
            (self.repo / 'stow' / name).mkdir(parents=True)
        (self.repo / 'defaults').mkdir()
        palette = self.repo / 'defaults/.config/rice/current-theme.conf'
        palette.parent.mkdir(parents=True)
        palette.write_text('name=fixture\n')
        src = self.repo / 'stow/desktop/.config/demo/config'
        src.parent.mkdir(parents=True)
        src.write_text('new\n')
        self.src = src
        self.rel = '.config/demo/config'
        self.patches = [patch.object(installer, 'REPO', self.repo),
                        patch.object(installer, 'TEMPLATES', {}),
                        patch.object(installer.shutil, 'which', return_value='/stub/stow')]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def stow_stub(self, args, **kwargs):
        """Model --no-folding only; real Stow is tested separately when installed."""
        self.assertIn('--no-folding', args)
        for rel, src in installer.sources().items():
            path = self.target / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            if not installer.exists(path):
                path.symlink_to(src)

    def backup(self):
        return sorted((self.target / '.local/state/rice/backups').iterdir())[-1]

    def deploy(self):
        with patch.object(installer.subprocess, 'run', side_effect=self.stow_stub):
            installer.deploy(self.target)

    def test_conflict_backup_and_restore(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.write_text('original\n')
        self.deploy()
        backup = self.backup()
        self.assertTrue(path.is_symlink())
        self.assertEqual((backup / 'files' / self.rel).read_text(), 'original\n')
        installer.restore(backup)
        self.assertEqual(path.read_text(), 'original\n')
        self.assertFalse(path.is_symlink())

    def test_broken_symlink_is_preserved(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.symlink_to('missing')
        self.deploy()
        installer.restore(self.backup())
        self.assertEqual(os.readlink(path), 'missing')

    def test_symlink_parent_does_not_modify_external_tree(self):
        outside = self.base / 'external'
        (outside / 'demo').mkdir(parents=True)
        (outside / 'demo/config').write_text('private\n')
        (self.target / '.config').symlink_to(outside, target_is_directory=True)
        self.deploy()
        self.assertEqual((outside / 'demo/config').read_text(), 'private\n')
        installer.restore(self.backup())
        self.assertTrue((self.target / '.config').is_symlink())

    def test_stow_failure_rolls_back_partial_links(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.write_text('original\n')
        def fail(*args, **kwargs):
            self.stow_stub(*args, **kwargs)
            raise subprocess.CalledProcessError(1, 'stow')
        with patch.object(installer.subprocess, 'run', side_effect=fail):
            with self.assertRaises(subprocess.CalledProcessError):
                installer.deploy(self.target)
        self.assertEqual(path.read_text(), 'original\n')

    def test_repeat_install_and_removed_source_cleanup(self):
        self.deploy()
        self.deploy()
        self.assertEqual((self.target / self.rel).resolve(), self.src)
        self.src.unlink()
        self.deploy()
        self.assertFalse(installer.exists(self.target / self.rel))

    def test_restore_refuses_subsequent_user_edits(self):
        self.deploy()
        path = self.target / self.rel
        path.unlink()
        path.write_text('later user change\n')
        with self.assertRaisesRegex(RuntimeError, 'Changed since installation'):
            installer.restore(self.backup())
        self.assertEqual(path.read_text(), 'later user change\n')

    def test_dry_run_leaves_target_untouched(self):
        installer.deploy(self.target, dry_run=True)
        self.assertEqual(list(self.target.iterdir()), [])


@unittest.skipUnless(shutil.which('stow'), 'GNU Stow unavailable: real integration not run')
class RealStowTest(unittest.TestCase):
    def test_full_deploy_and_restore_in_disposable_home(self):
        with tempfile.TemporaryDirectory(prefix='rice-real-stow-') as directory:
            target = Path(directory)
            installer.deploy(target)
            for rel, src in installer.sources().items():
                self.assertTrue((target / rel).is_symlink(), rel)
                self.assertEqual((target / rel).resolve(), src)
            self.assertNotIn('/home/bingxyi/', (target / '.config/tint2/tint2rc').read_text())
            backup = next((target / '.local/state/rice/backups').iterdir())
            installer.restore(backup)
            self.assertFalse((target / '.config/bspwm/bspwmrc').exists())


if __name__ == '__main__':
    unittest.main()
