"""Repeatable control actions against simulated services, never live radios/DPMS."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

BIN=Path(__file__).resolve().parents[1]/'stow/desktop/.config/rice/bin'
sys.path.insert(0,str(BIN))
import control_action

STUB='''#!/usr/bin/env python3
import json,os,pathlib,sys,time
root=pathlib.Path(os.environ['FIXTURE']);name=pathlib.Path(sys.argv[0]).name;args=sys.argv[1:]
with (root/'calls.jsonl').open('a') as stream:stream.write(json.dumps([name,*args])+'\\n')
if name=='xset' and args==['q']:
 print('  timeout:  600    cycle:  600\\n  Standby: 720    Suspend: 780    Off: 840\\n  DPMS is Enabled')
elif name=='systemd-inhibit':time.sleep(60)
elif name=='powerprofilesctl':
 p=root/'power'
 if args==['get']:print(p.read_text())
 elif args==['list']:
  print('  balanced:\\n  power-saver:' if (root/'no-performance').exists() else '  balanced:\\n  performance:\\n  power-saver:')
 elif args[0]=='set':p.write_text(args[1])
elif name=='dunstctl':
 p=root/'dnd'
 if args==['is-paused']:print(p.read_text())
 elif args[0]=='set-paused':p.write_text(args[1])
elif name=='nmcli':
 p=root/'wifi'
 if args==['radio','wifi']:print(p.read_text())
 elif args[:2]==['radio','wifi']:p.write_text('enabled' if args[2]=='on' else 'disabled')
 elif 'NAME,TYPE' in args:print('Fixture:802-11-wireless')
 elif 'TYPE' in args:print('802-11-wireless')
 elif 'ACTIVE,SSID' in args:print('yes:Fixture')
elif name=='wpctl':
 p=root/'volume';v=p.read_text()
 if args[0]=='get-volume':print('Volume: '+str(float(v)/100))
 elif args[0]=='set-volume':
  value=args[-1]
  if value.endswith('%'):p.write_text(value[:-1])
'''


class ToggleTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        config=self.root/'.config/rice/bin';config.mkdir(parents=True)
        for name in ['lib.sh','caffeine.sh','powerprofile.sh','network.sh','notifications.sh','volume.sh']:
            shutil.copy2(BIN/name,config/name)
        shutil.copy2(BIN.parent/'env',config.parent/'env')
        stubdir=self.root/'bin';stubdir.mkdir()
        for name in ['xset','systemd-inhibit','eww','notify-send','powerprofilesctl','nmcli','dunstctl','wpctl','nvidia-settings']:
            path=stubdir/name;path.write_text(STUB);path.chmod(0o755)
        for name,value in [('power','balanced'),('wifi','enabled'),('dnd','false'),('volume','40')]:
            (self.root/name).write_text(value)
        self.env={**os.environ,'HOME':str(self.root),'XDG_DATA_HOME':str(self.root/'share'),
                  'PATH':str(stubdir)+':'+os.environ['PATH'],'FIXTURE':str(self.root),'DISPLAY':':fixture'}

    def tearDown(self):
        pidfile=self.root/'share/rice/caffeine.pid'
        if pidfile.exists():
            try:os.killpg(int(pidfile.read_text()),signal.SIGTERM)
            except (OSError,ValueError):pass
        self.temp.cleanup()

    def script(self,name,*args):
        result=subprocess.run(['bash',str(BIN/name),*args],env=self.env,capture_output=True,text=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr);return result.stdout.strip()

    def calls(self):
        p=self.root/'calls.jsonl'
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []

    def test_caffeine_four_consecutive_clicks_update_state_and_restore_original_dpms(self):
        for expected in ['on','off','on','off']:
            self.script('caffeine.sh','--toggle')
            self.assertEqual(self.script('caffeine.sh','--status'),expected)
            self.assertTrue(any(call[0]=='eww' and 'caffeine='+expected in call for call in self.calls()))
        self.assertIn(['xset','dpms','720','780','840'],self.calls())
        self.assertIn(['xset','s','600','600'],self.calls())

    def test_power_cycle_updates_profile_and_label_together(self):
        for expected,label in [('performance','Performance'),('power','Power saver'),('balanced','Balanced')]:
            self.script('powerprofile.sh','--cycle')
            self.assertEqual(self.script('powerprofile.sh','--get'),expected)
            self.assertTrue(any(call[0]=='eww' and 'power_profile='+expected in call and 'power_label='+label in call for call in self.calls()))

    def test_power_cycle_skips_unavailable_performance_mode(self):
        (self.root/'no-performance').touch()
        self.script('powerprofile.sh','--cycle')
        self.assertEqual(self.script('powerprofile.sh','--get'),'power')
        self.script('powerprofile.sh','--cycle')
        self.assertEqual(self.script('powerprofile.sh','--get'),'balanced')

    def test_dnd_repeated_clicks_immediately_push_visual_state(self):
        for expected in ['dnd','on','dnd','on']:
            self.script('notifications.sh','--dnd')
            self.assertEqual(self.script('notifications.sh','--status'),expected)
            self.assertTrue(any(call[0]=='eww' and 'dnd='+expected in call for call in self.calls()))

    def test_wifi_repeated_clicks_do_not_report_stale_state(self):
        for expected in ['off','on','off','on']:
            self.script('network.sh','--wifi-toggle')
            self.assertEqual(self.script('network.sh','--wifi-state'),expected)
            self.assertTrue(any(call[0]=='eww' and 'wifi_state='+expected in call for call in self.calls()))

    def test_clear_notifications_clears_only_fixture_history_and_refreshes_count(self):
        history=self.root/'share/rice/notifications.json';history.parent.mkdir(parents=True,exist_ok=True)
        history.write_text('{"summary":"fixture"}\n')
        self.script('notifications.sh','--clear')
        self.assertEqual(history.read_text(),'')
        self.assertIn(['dunstctl','close-all'],self.calls())
        self.assertIn(['dunstctl','history-clear'],self.calls())
        self.assertTrue(any(c[0]=='eww' and 'notif_count=0' in c for c in self.calls()))

    def test_volume_accepts_real_scale_values_and_updates_audio_states(self):
        self.script('volume.sh','--set','43.7')
        self.assertEqual((self.root/'volume').read_text(),'44')
        self.assertTrue(any(c[0]=='eww' and 'volume=44' in c and 'mic_muted=off' in c for c in self.calls()))


class DispatchTests(unittest.TestCase):
    def test_failure_restores_clickability_and_surfaces_error(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ,{'XDG_RUNTIME_DIR':directory}), \
             patch.object(control_action,'update') as update, \
             patch.object(control_action.subprocess,'run',return_value=subprocess.CompletedProcess([],1,'','Service unavailable')):
            self.assertEqual(control_action.perform('power'),1)
        self.assertEqual(update.call_args_list[0].kwargs,{'cc_busy':True,'cc_error':'','cc_active_action':'power'})
        self.assertEqual(update.call_args_list[-1].kwargs,{'cc_busy':False,'cc_active_action':''})
        self.assertTrue(any('Service unavailable' in c.kwargs.get('cc_error','') for c in update.call_args_list))

    def test_date_is_validated_before_launching_event_editor(self):
        with self.assertRaises(ValueError):control_action.perform('events','2026-99-01')
        with self.assertRaises(ValueError):control_action.perform('wifi','2026-11-04')

    def test_visual_state_does_not_disable_custom_tile(self):
        text=(BIN.parents[1]/'eww/eww.yuck').read_text()
        self.assertIn('qs_tile [icon title subtitle selected onclick]',text)
        self.assertNotIn('qs_tile [icon title subtitle active onclick]',text)
        self.assertNotIn(':sensitive',text)

    def test_unknown_action_cannot_execute_arbitrary_commands(self):
        with self.assertRaises(ValueError):control_action.perform('power; unexpected command')

    def test_tiles_have_deadline_and_each_dispatch_action_is_known(self):
        text=(BIN.parents[1]/'eww/eww.yuck').read_text()
        self.assertIn(':timeout "15s"',text)
        for action in ['wifi','dnd','power','caffeine','vpn','proxy','theme','screenshot','bluetooth','binds','mute','microphone']:
            self.assertIn('control_action.py '+action,text)
            self.assertIn(action,{**control_action.TOGGLES,**control_action.MENUS})


if __name__=='__main__':unittest.main()
