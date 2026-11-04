"""Locker regression tests with fake lockers; never lock the user's session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

BIN=Path(__file__).resolve().parents[1]/'stow/desktop/.config/rice/bin'

class LockTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        config=self.root/'.config/rice/bin';config.mkdir(parents=True)
        for name in ('lib.sh','lock.sh'):shutil.copy2(BIN/name,config/name)
        self.bindir=self.root/'bin';self.bindir.mkdir()
        for name in ('betterlockscreen','i3lock','xrandr','bspc','notify-send'):
            p=self.bindir/name;p.write_text('''#!/usr/bin/env python3
import os,json,sys,time
from pathlib import Path
name=Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as f:f.write(json.dumps([name,*sys.argv[1:]])+'\\n')
if name=='betterlockscreen':
 time.sleep(float(os.environ.get('LOCK_SLEEP','0')))
 sys.exit(int(os.environ.get('LOCK_FAIL','0')))
''');p.chmod(0o755)
        self.env={**os.environ,'HOME':str(self.root),'XDG_DATA_HOME':str(self.root/'data'),
                  'XDG_RUNTIME_DIR':str(self.root),'PATH':str(self.bindir)+':'+os.environ['PATH'],
                  'CALLS':str(self.root/'calls')}

    def tearDown(self):self.tmp.cleanup()
    def run_lock(self,*args):return subprocess.run(['bash',str(BIN/'lock.sh'),*args],env=self.env,capture_output=True,text=True,timeout=4)
    def calls(self):return [json.loads(s) for s in (self.root/'calls').read_text().splitlines()]

    def test_lock_uses_prepared_image_without_randr_or_render_work(self):
        self.assertEqual(self.run_lock().returncode,0)
        self.assertEqual(self.calls(),[['betterlockscreen','--lock','dimblur','--off','300']])

    def test_keep_monitors_compatibility_alias(self):
        self.assertEqual(self.run_lock('--keep-monitors').returncode,0)
        self.assertEqual(self.calls()[0][1],'--lock')

    def test_failed_themed_locker_falls_back_to_foreground_secure_locker(self):
        self.env['LOCK_FAIL']='1'
        self.assertEqual(self.run_lock().returncode,0)
        self.assertEqual(self.calls()[-1],['i3lock','-c','1e1e2e','--nofork'])

    def test_duplicate_invocation_does_not_start_competing_locker(self):
        import time
        self.env['LOCK_SLEEP']='.7'
        p=subprocess.Popen(['bash',str(BIN/'lock.sh')],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            deadline=time.monotonic()+2
            while not (self.root/'calls').exists() and time.monotonic()<deadline:time.sleep(.01)
            self.assertEqual(self.run_lock().returncode,0)
        finally:p.wait(timeout=3)
        self.assertEqual(len(self.calls()),1)

if __name__=='__main__':unittest.main()
