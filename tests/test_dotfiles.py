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
        self.temp = tempfile.TemporaryDirectory(prefix='rice copy ')
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo with spaces'
        self.target = self.base / 'home with spaces'
        self.target.mkdir()
        for name in installer.PACKAGES:
            (self.repo / 'stow' / name).mkdir(parents=True)
        (self.repo / 'defaults/.config/rice').mkdir(parents=True)
        (self.repo / 'defaults/.config/rice/current-theme.conf').write_text('name=fixture\n')
        self.rel = '.config/demo/config'
        self.src = self.repo / 'stow/desktop' / self.rel
        self.src.parent.mkdir(parents=True)
        self.src.write_text('new\n')
        self.src.chmod(0o755)
        self.patches = [patch.object(installer, 'REPO', self.repo),
                        patch.object(installer, 'TEMPLATES', {})]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.temp.cleanup()

    def backup(self):
        return max((self.target / '.local/state/rice/backups').iterdir(), key=lambda p: p.stat().st_mtime_ns)

    def deploy(self, **kwargs):
        installer.deploy(self.target, **kwargs)

    def test_python_bytecode_is_not_part_of_the_distribution_payload(self):
        generated=self.src.parent/'__pycache__'/'module.cpython-314.pyc'
        generated.parent.mkdir();generated.write_bytes(b'generated')
        (self.src.parent/'loose.pyc').write_bytes(b'generated')
        result=installer.sources()
        self.assertIn(self.rel,result)
        self.assertFalse(any('__pycache__' in name or name.endswith('.pyc') for name in result))

    def test_regular_copy_backup_and_restore(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.write_text('original\n')
        self.deploy()
        backup = self.backup()
        self.assertFalse(path.is_symlink())
        self.assertEqual(path.read_text(), 'new\n')
        self.assertEqual(path.stat().st_mode & 0o777, 0o755)
        self.src.write_text('repo changed later\n')
        self.assertEqual(path.read_text(), 'new\n')
        installer.restore(backup)
        self.assertEqual(path.read_text(), 'original\n')

    def test_legacy_links_become_independent_files_with_content_backup(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.symlink_to(self.src)
        self.deploy()
        self.assertFalse(path.is_symlink())
        backup = self.backup()
        self.assertTrue((backup / 'files' / self.rel).is_symlink())
        self.assertEqual((backup / 'resolved' / self.rel).read_text(), 'new\n')
        installer.restore(backup)
        self.assertTrue(path.is_symlink())

    def test_broken_symlink_is_preserved_for_restore(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.symlink_to('missing')
        self.deploy()
        installer.restore(self.backup())
        self.assertEqual(os.readlink(path), 'missing')

    def test_symlink_parent_stops_before_changes(self):
        outside = self.base / 'external'
        (outside / 'demo').mkdir(parents=True)
        (outside / 'demo/config').write_text('private\n')
        (self.target / '.config').symlink_to(outside, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, 'ancestor'):
            self.deploy()
        self.assertEqual((outside / 'demo/config').read_text(), 'private\n')
        self.assertFalse((self.target / '.local').exists())

    def test_copy_failure_rolls_back_previously_written_files(self):
        path = self.target / self.rel
        path.parent.mkdir(parents=True)
        path.write_text('original\n')
        original = installer.os.replace
        def fail(source, dest):
            if str(dest).endswith(installer.INVENTORY) and Path(dest).is_relative_to(self.target):
                raise OSError('simulated copy failure')
            return original(source, dest)
        with patch.object(installer.os, 'replace', side_effect=fail):
            with self.assertRaisesRegex(OSError, 'simulated'):
                self.deploy()
        self.assertEqual(path.read_text(), 'original\n')

    def test_bad_template_is_caught_before_live_changes(self):
        with patch.object(installer, 'render', side_effect=RuntimeError('bad template')):
            with self.assertRaisesRegex(RuntimeError, 'bad template'):
                self.deploy()
        self.assertEqual(list(self.target.iterdir()), [])

    def test_repeat_install_and_removed_unchanged_source_cleanup(self):
        self.deploy()
        self.deploy()
        self.src.unlink()
        self.deploy()
        self.assertFalse(installer.exists(self.target / self.rel))

    def test_direct_local_edits_stop_update_without_losing_work(self):
        self.deploy()
        path = self.target / self.rel
        path.write_text('edited directly in config\n')
        self.src.write_text('new upstream version\n')
        before = len(list((self.target / '.local/state/rice/backups').iterdir()))
        with self.assertRaisesRegex(RuntimeError, 'Local edits retained'):
            self.deploy()
        self.assertEqual(path.read_text(), 'edited directly in config\n')
        self.assertEqual(len(list((self.target / '.local/state/rice/backups').iterdir())), before)

    def test_explicit_overwrite_keeps_local_edit_in_backup(self):
        self.deploy()
        path = self.target / self.rel
        path.write_text('personal edit\n')
        self.deploy(overwrite_local=True)
        self.assertEqual((self.backup() / 'files' / self.rel).read_text(), 'personal edit\n')
        self.assertEqual(path.read_text(), 'new\n')

    def test_removed_source_does_not_delete_edited_copy(self):
        self.deploy()
        path = self.target / self.rel
        path.write_text('personal edit\n')
        self.src.unlink()
        self.deploy()
        self.assertEqual(path.read_text(), 'personal edit\n')

    def test_restore_refuses_subsequent_user_edits(self):
        self.deploy()
        path = self.target / self.rel
        path.write_text('later user change\n')
        with self.assertRaisesRegex(RuntimeError, 'Changed since installation'):
            installer.restore(self.backup())
        self.assertEqual(path.read_text(), 'later user change\n')

    def test_dry_run_leaves_target_untouched(self):
        installer.deploy(self.target, dry_run=True)
        self.assertEqual(list(self.target.iterdir()), [])

    def test_keep_monitors_preserves_personal_script(self):
        rel = '.config/bspwm/monitors.sh'
        source = self.repo / 'stow/desktop' / rel
        source.parent.mkdir(parents=True)
        source.write_text('portable monitors\n')
        path = self.target / rel
        path.parent.mkdir(parents=True)
        path.write_text('private\n')
        self.deploy(keep_monitors=True)
        self.assertEqual(path.read_text(), 'private\n')
        self.assertFalse(path.is_symlink())

    def test_notebook_hook_migration_and_rollback_preserve_permissions(self):
        path = self.target / '.config/bspwm/local.sh'
        path.parent.mkdir(parents=True)
        original = ('#!/bin/bash\nOFFSEC_BIN="$HOME/.config/offsec/bin"\n'
                    'xset s 600 600\n    autorandr --change --default default 2>/dev/null &\n')
        path.write_text(original)
        path.chmod(0o755)
        self.deploy()
        self.assertIn('$HOME/.config/rice/bin', path.read_text())
        self.assertNotIn('autorandr --change', path.read_text())
        self.assertEqual(path.stat().st_mode & 0o777, 0o755)
        installer.restore(self.backup())
        self.assertEqual(path.read_text(), original)

    def test_missing_dependencies_stop_before_deployment(self):
        with patch.object(installer.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'Missing session dependencies'):
                installer.check_dependencies()
        self.assertEqual(list(self.target.iterdir()), [])

    def test_missing_kitty_shell_is_reported_before_deployment(self):
        which = shutil.which
        with patch.object(installer.shutil, 'which', side_effect=lambda name: None if name == 'fish' else which(name)):
            with self.assertRaisesRegex(RuntimeError, r'Missing session dependencies.*fish'):
                installer.check_dependencies()
        self.assertEqual(list(self.target.iterdir()), [])


class RealCopyTest(unittest.TestCase):
    def test_fish_default_is_installed_but_existing_config_is_preserved(self):
        with tempfile.TemporaryDirectory(prefix='rice-fish-') as directory:
            target = Path(directory)
            path = target / '.config/fish/config.fish'
            installer.deploy(target)
            self.assertEqual(path.read_bytes(), (ROOT / 'defaults/.config/fish/config.fish').read_bytes())
            path.write_text('# My existing shell config\nset -g fish_greeting hello\n')
            installer.deploy(target)
            self.assertEqual(path.read_text(), '# My existing shell config\nset -g fish_greeting hello\n')

    def test_full_deploy_and_restore_in_disposable_home(self):
        with tempfile.TemporaryDirectory(prefix='rice-real-copy-') as directory:
            target = Path(directory)
            installer.deploy(target)
            for rel, src in installer.sources().items():
                self.assertFalse((target / rel).is_symlink(), rel)
                self.assertEqual((target / rel).read_bytes(), src.read_bytes(), rel)
            self.assertNotIn('/home/bingxyi/', (target / '.config/tint2/tint2rc').read_text())
            self.assertIn(str(target / '.config/rice/bin'), (target / '.config/tint2/tint2rc').read_text())
            self.assertNotIn('/tmp/rice-deploy-', (target / '.config/tint2/tint2rc').read_text())
            backup = next((target / '.local/state/rice/backups').iterdir())
            installer.restore(backup)
            self.assertFalse((target / '.config/bspwm/bspwmrc').exists())


if __name__ == '__main__':
    unittest.main()
