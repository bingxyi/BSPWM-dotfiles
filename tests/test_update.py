"""Three-way updates use disposable repositories and homes, never the session."""
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
spec = importlib.util.spec_from_file_location('merge_installer', ROOT / 'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)
BASE = b'first\n' + b'middle\n' * 12 + b'last\n'


class MergeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rice merge ')
        self.root = Path(self.temp.name)
        self.repo = self.root / 'repo'
        self.home = self.root / 'home'
        self.home.mkdir()
        for name in installer.PACKAGES:
            (self.repo / 'stow' / name).mkdir(parents=True)
        (self.repo / 'defaults/.config/rice').mkdir(parents=True)
        (self.repo / 'defaults/.config/rice/current-theme.conf').write_text('name=fixture\n')
        (self.repo / 'scripts').mkdir()
        (self.repo / 'scripts/check.py').write_text('raise SystemExit(0)\n')
        self.rel = '.config/demo/config'
        self.source = self.repo / 'stow/desktop' / self.rel
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(BASE)
        self.local = self.home / self.rel
        self.patches = [patch.object(installer, 'REPO', self.repo), patch.object(installer, 'TEMPLATES', {})]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in reversed(self.patches):
            p.stop()
        self.temp.cleanup()

    def deploy(self, **kwargs):
        installer.deploy(self.home, **kwargs)

    def independent_edits(self):
        self.local.write_bytes(BASE.replace(b'first', b'personal'))
        self.source.write_bytes(BASE.replace(b'last', b'upstream'))

    def snapshot(self):
        return {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob('*') if p.is_file()}

    def test_independent_edits_merge_and_survive_second_update_and_restore(self):
        self.deploy()
        self.independent_edits()
        self.deploy(merge_local=True)
        expected = BASE.replace(b'first', b'personal').replace(b'last', b'upstream')
        self.assertEqual(self.local.read_bytes(), expected)
        state = json.loads((self.home / installer.INVENTORY).read_text())
        self.assertEqual(state['schema'], 3)
        digest = state['upstream'][self.rel]['sha256']
        self.assertEqual((self.home / installer.BASES / digest).read_bytes(), self.source.read_bytes())
        self.source.write_bytes(BASE.replace(b'last', b'upstream2'))
        self.deploy(merge_local=True)
        self.assertIn(b'personal', self.local.read_bytes())
        self.assertIn(b'upstream2', self.local.read_bytes())
        backup = max((self.home / '.local/state/rice/backups').iterdir(), key=lambda p: p.stat().st_mtime_ns)
        installer.restore(backup)
        self.assertEqual(self.local.read_bytes(), expected)

    def test_overlapping_edit_aborts_all_files_without_markers_or_backup(self):
        self.deploy()
        self.local.write_bytes(BASE.replace(b'first', b'local'))
        self.source.write_bytes(BASE.replace(b'first', b'remote'))
        other = self.source.parent / 'other'
        other.write_text('new file')
        before = self.snapshot()
        with self.assertRaisesRegex(RuntimeError, 'overlapping edits'):
            self.deploy(merge_local=True)
        self.assertEqual(self.snapshot(), before)

    def test_dry_run_merges_without_writing_home(self):
        self.deploy()
        self.independent_edits()
        before = self.snapshot()
        self.deploy(merge_local=True, dry_run=True)
        self.assertEqual(self.snapshot(), before)

    def test_corrupt_baseline_is_not_used(self):
        self.deploy()
        state = json.loads((self.home / installer.INVENTORY).read_text())
        (self.home / installer.BASES / state['upstream'][self.rel]['sha256']).write_bytes(b'corrupt')
        self.independent_edits()
        before = self.snapshot()
        with self.assertRaisesRegex(RuntimeError, 'Corrupt merge baseline'):
            self.deploy(merge_local=True)
        self.assertEqual(self.snapshot(), before)

    def test_locally_deleted_file_is_not_resurrected(self):
        self.deploy()
        self.local.unlink()
        with self.assertRaisesRegex(RuntimeError, 'locally deleted'):
            self.deploy(merge_local=True)
        self.assertFalse(self.local.exists())

    def test_upstream_removal_keeps_previously_merged_personal_file(self):
        self.deploy()
        self.independent_edits()
        self.deploy(merge_local=True)
        expected = self.local.read_bytes()
        self.source.unlink()
        self.deploy(merge_local=True)
        self.assertEqual(self.local.read_bytes(), expected)

    def test_invalid_combined_payload_stops_before_home_changes(self):
        self.deploy()
        self.independent_edits()
        (self.repo / 'scripts/check.py').write_text('raise SystemExit(1)\n')
        before = self.snapshot()
        with self.assertRaises(subprocess.CalledProcessError):
            self.deploy(merge_local=True)
        self.assertEqual(self.snapshot(), before)

    def test_generated_file_edits_are_merged_with_new_render(self):
        rel = '.config/generated.conf'
        def render(stage, home=None):
            (stage / rel).write_bytes(self.source.read_bytes())
        with patch.object(installer, 'TEMPLATES', {'demo.tpl': rel}), patch.object(installer, 'render', side_effect=render):
            self.deploy()
            (self.home / rel).write_bytes(BASE.replace(b'first', b'personal'))
            self.source.write_bytes(BASE.replace(b'last', b'remote'))
            self.deploy(merge_local=True)
            self.assertEqual((self.home / rel).read_bytes(), BASE.replace(b'first', b'personal').replace(b'last', b'remote'))

    def test_schema2_recovers_exact_base_from_git_history(self):
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        def commit():
            subprocess.run(['git', '-C', str(self.repo), 'add', '.'], check=True)
            subprocess.run(['git', '-C', str(self.repo), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        commit()
        self.deploy()
        inventory = self.home / installer.INVENTORY
        state = json.loads(inventory.read_text())
        state.pop('upstream'); state['schema'] = 2
        inventory.write_text(json.dumps(state))
        self.independent_edits()
        commit()
        self.deploy(merge_local=True)
        self.assertEqual(self.local.read_bytes(), BASE.replace(b'first', b'personal').replace(b'last', b'upstream'))

    def test_missing_schema2_base_never_guesses(self):
        self.deploy()
        inventory = self.home / installer.INVENTORY
        state = json.loads(inventory.read_text()); state.pop('upstream'); state['schema'] = 2
        inventory.write_text(json.dumps(state))
        self.independent_edits()
        with self.assertRaisesRegex(RuntimeError, 'Merge stopped'):
            self.deploy(merge_local=True)

    def test_binary_changes_are_only_accepted_when_unambiguous(self):
        self.assertEqual(installer.merge_bytes(b'a\0', b'a\0', b'b\0'), b'b\0')
        self.assertEqual(installer.merge_bytes(b'l\0', b'a\0', b'a\0'), b'l\0')
        with self.assertRaisesRegex(RuntimeError, 'binary'):
            installer.merge_bytes(b'l\0', b'a\0', b'r\0')


class UpdateEntryTests(unittest.TestCase):
    def test_help_and_dirty_checkout_do_not_install(self):
        with tempfile.TemporaryDirectory(prefix='rice-updater-') as directory:
            repo = Path(directory) / 'repo'
            home = Path(directory) / 'home'
            home.mkdir(); (repo / 'scripts').mkdir(parents=True)
            shutil.copy2(ROOT / 'update.sh', repo / 'update.sh')
            shutil.copy2(ROOT / 'scripts/update.py', repo / 'scripts/update.py')
            subprocess.run(['git', 'init', '-q', str(repo)], check=True)
            result = subprocess.run([str(repo / 'update.sh'), '--target', str(home), '--no-fetch'], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Checkout has local changes', result.stderr)
            self.assertEqual(list(home.iterdir()), [])
            result = subprocess.run([str(repo / 'update.sh'), '--help'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)
            self.assertIn('--dry-run', result.stdout)


class RemoteUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='rice remote ')
        self.root = Path(self.temp.name)
        self.seed = self.root / 'seed'
        self.remote = self.root / 'remote.git'
        self.client = self.root / 'client'
        self.home = self.root / 'home'
        self.home.mkdir()
        subprocess.run(['git', 'init', '-q', '--bare', '--initial-branch=main', str(self.remote)], check=True)
        subprocess.run(['git', 'init', '-q', '--initial-branch=main', str(self.seed)], check=True)
        for name in installer.PACKAGES:
            (self.seed / 'stow' / name).mkdir(parents=True)
        (self.seed / 'scripts').mkdir()
        (self.seed / 'tests').mkdir()
        (self.seed / 'defaults/.config/rice').mkdir(parents=True)
        (self.seed / 'defaults/.config/rice/current-theme.conf').write_text('name=fixture\n')
        for name in ('install.sh', 'update.sh'):
            shutil.copy2(ROOT / name, self.seed / name)
        shutil.copy2(ROOT / 'scripts/update.py', self.seed / 'scripts/update.py')
        source = (ROOT / 'scripts/install.py').read_text()
        start = source.index('TEMPLATES = {')
        end = source.index('\nBASES = ', start)
        (self.seed / 'scripts/install.py').write_text(source[:start] + 'TEMPLATES = {}\n' + source[end:])
        (self.seed / 'scripts/check.py').write_text('raise SystemExit(0)\n')
        (self.seed / 'tests/test_fixture.py').write_text('import unittest\nclass Smoke(unittest.TestCase):\n def test_smoke(self): self.assertTrue(True)\n')
        (self.seed / '.gitignore').write_text('.install.lock\n__pycache__/\n')
        self.rel = '.config/demo/config'
        self.upstream = self.seed / 'stow/desktop' / self.rel
        self.upstream.parent.mkdir(parents=True)
        self.upstream.write_bytes(BASE)
        self.git(self.seed, 'add', '.')
        self.git(self.seed, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'initial')
        self.git(self.seed, 'remote', 'add', 'origin', str(self.remote))
        self.git(self.seed, 'push', '-qu', 'origin', 'main')
        subprocess.run(['git', 'clone', '-q', str(self.remote), str(self.client)], check=True)
        subprocess.run([str(self.client / 'install.sh'), '--target', str(self.home)], check=True, capture_output=True)
        self.old_head = self.git(self.client, 'rev-parse', 'HEAD')

    def tearDown(self):
        self.temp.cleanup()

    def git(self, repo, *args):
        return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()

    def push(self):
        self.git(self.seed, 'add', '.')
        self.git(self.seed, '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'incoming')
        self.git(self.seed, 'push', '-q')

    def update(self, *args):
        return subprocess.run([str(self.client / 'update.sh'), '--target', str(self.home), *args], capture_output=True, text=True, timeout=30)

    def test_remote_fetch_preview_then_install_preserves_personal_edit(self):
        local = self.home / self.rel
        local.write_bytes(BASE.replace(b'first', b'personal'))
        self.upstream.write_bytes(BASE.replace(b'last', b'new upstream'))
        self.push()
        result = self.update('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git(self.client, 'rev-parse', 'HEAD'), self.old_head)
        self.assertEqual(local.read_bytes(), BASE.replace(b'first', b'personal'))
        result = self.update('--no-fetch')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(local.read_bytes(), BASE.replace(b'first', b'personal').replace(b'last', b'new upstream'))
        self.assertEqual(self.git(self.client, 'rev-parse', 'HEAD'), self.git(self.seed, 'rev-parse', 'HEAD'))
        self.assertEqual(self.git(self.client, 'status', '--porcelain'), '')
        self.assertEqual(self.git(self.client, 'worktree', 'list', '--porcelain').count('worktree '), 1)

    def test_remote_conflict_leaves_checkout_and_home_intact(self):
        local = self.home / self.rel
        local.write_bytes(BASE.replace(b'first', b'personal'))
        self.upstream.write_bytes(BASE.replace(b'first', b'upstream'))
        self.push()
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('overlapping edits', result.stderr)
        self.assertEqual(self.git(self.client, 'rev-parse', 'HEAD'), self.old_head)
        self.assertEqual(local.read_bytes(), BASE.replace(b'first', b'personal'))
        self.assertEqual(self.git(self.client, 'worktree', 'list', '--porcelain').count('worktree '), 1)

    def test_rejected_incoming_checks_do_not_advance_checkout(self):
        (self.seed / 'scripts/check.py').write_text('raise SystemExit(1)\n')
        self.push()
        result = self.update()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.git(self.client, 'rev-parse', 'HEAD'), self.old_head)
        self.assertEqual((self.home / self.rel).read_bytes(), BASE)
