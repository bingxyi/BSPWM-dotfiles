"""Do not black out the desktop when the compositor is unavailable."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'stow/desktop/.config/rice/bin'

class PanelTests(unittest.TestCase):
    def test_eww_background_child_cannot_keep_popup_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            rice = root / '.config/rice'
            (rice / 'bin').mkdir(parents=True)
            shutil.copy2(BIN.parent / 'env', rice / 'env')
            stub = root / 'bin'
            stub.mkdir()
            eww = stub / 'eww'
            eww.write_text('''#!/usr/bin/env python3
import os, pathlib, subprocess, sys
if 'active-windows' in sys.argv:
    try:
        os.fstat(9)
    except OSError:
        inherited = ()
    else:
        inherited = (9,)
    child = subprocess.Popen(['sleep', '30'], pass_fds=inherited,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
    pathlib.Path(os.environ['CHILD_PID']).write_text(str(child.pid))
''')
            eww.chmod(0o755)
            runtime = root / 'runtime'
            pidfile = root / 'child.pid'
            env = {**os.environ, 'HOME': str(root), 'XDG_RUNTIME_DIR': str(runtime),
                   'PATH': str(stub) + ':' + os.environ['PATH'], 'CHILD_PID': str(pidfile)}
            try:
                result = subprocess.run(['bash', str(BIN / 'panel.sh'), 'close', 'control'],
                                        env=env, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 0, result.stderr)
                probe = subprocess.run(['flock', '-n', str(runtime / 'rice-popup.lock'), 'true'])
                self.assertEqual(probe.returncode, 0, 'Eww child inherited the popup lock')
            finally:
                if pidfile.exists():
                    try:
                        os.kill(int(pidfile.read_text()), signal.SIGTERM)
                    except ProcessLookupError:
                        pass

    def test_no_fullscreen_backdrop_when_compositor_selection_has_no_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);rice=root/'.config/rice';(rice/'bin').mkdir(parents=True)
            shutil.copy2(BIN.parent/'env',rice/'env')
            probe=rice/'bin/animation_settings.py';probe.write_text('#!/bin/sh\nexit 1\n');probe.chmod(0o755)
            stub=root/'bin';stub.mkdir()
            program='''#!/usr/bin/env python3
import json,os,sys,pathlib
name=pathlib.Path(sys.argv[0]).name
with open(os.environ['CALLS'],'a') as f:f.write(json.dumps([name,*sys.argv[1:]])+'\\n')
if name=='xrandr':print('Monitors: 1\\n 0: +*eDP-1 1920/344x1080/193+0+0 eDP-1')
'''
            for name in ['eww','xrandr','sxhkd']:
                p=stub/name;p.write_text(program);p.chmod(0o755)
            calls=root/'calls';env={**os.environ,'HOME':str(root),'XDG_RUNTIME_DIR':str(root/'runtime'),'PATH':str(stub)+':'+os.environ['PATH'],'CALLS':str(calls)}
            result=subprocess.run(['bash',str(BIN/'panel.sh'),'open','control'],env=env,capture_output=True,text=True,timeout=4)
            self.assertEqual(result.returncode,0,result.stderr)
            commands=[json.loads(line) for line in calls.read_text().splitlines()]
            self.assertTrue(any(c[0]=='eww' and 'control' in c for c in commands))
            self.assertFalse(any('cc_backdrop' in c for c in commands))

    def test_recovery_mode_selects_the_basic_config_without_probing_animation_engine(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);rice=root/'.config/rice';(rice/'bin').mkdir(parents=True)
            shutil.copy2(BIN/'lib.sh',rice/'bin/lib.sh')
            (rice/'compositor-safe-mode').write_text('Emergency display recovery')
            env={**os.environ,'HOME':str(root),'LAUNCH_SOURCE':str(BIN/'picom-launch.sh')}
            result=subprocess.run(['bash','-c','. "$LAUNCH_SOURCE"; pick_config'],env=env,capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout,str(root/'.config/picom/picom-basic.conf'))

    def test_compositor_child_survives_the_applicator_process_in_a_separate_session(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);config=root/'.config/rice/bin';config.mkdir(parents=True)
            shutil.copy2(BIN/'lib.sh',config/'lib.sh')
            runner=config/'animation_settings.py';runner.write_text('''#!/usr/bin/env python3
import os,json,time
open(os.environ['PID_CAPTURE'],'w').write(json.dumps({'pid':os.getpid(),'sid':os.getsid(0)}))
time.sleep(10)
''');runner.chmod(0o755)
            output=root/'pid.json';env={**os.environ,'HOME':str(root),'XDG_DATA_HOME':str(root/'share'),'PID_CAPTURE':str(output)}
            command='. "$LAUNCH_SOURCE"; start_picom dummy'
            env['LAUNCH_SOURCE']=str(BIN/'picom-launch.sh')
            pid=None
            try:
                parent=subprocess.run(['bash','-c',command],env=env,capture_output=True,text=True,timeout=5)
                self.assertEqual(parent.returncode,0,parent.stderr)
                state=json.loads(output.read_text());pid=state['pid']
                os.kill(pid,0)
                self.assertEqual(state['sid'],pid)
                self.assertNotEqual(state['sid'],os.getsid(0))
            finally:
                if pid:
                    try:os.kill(pid,signal.SIGTERM)
                    except ProcessLookupError:pass

if __name__=='__main__':unittest.main()
