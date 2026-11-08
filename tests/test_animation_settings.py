"""Animation preferences, config preservation, rollback and real frame pacing."""
from copy import deepcopy
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
BIN=ROOT/'stow/desktop/.config/rice/bin';sys.path.insert(0,str(BIN))
import animation_settings as settings

class SettingsTests(unittest.TestCase):
    def test_default_ft_spring_reaches_destination_without_a_long_tail(self):
        # Same semi-implicit integration and destination clamp as FT-Labs df4c6.
        s=settings.validate({})
        for hz in (60,120,144):
            distance=1.;velocity=0.;frames=0
            while distance>1e-9 and frames<hz*2:
                velocity+=(-s['stiffness']*distance-s['damping']*velocity)/s['mass']/hz
                distance=max(0.,min(distance,distance+velocity/hz));frames+=1
            self.assertTrue(s['clamping'])
            self.assertLess(frames/hz,.25)

    def test_defaults_are_enabled_and_really_request_sixty_fps(self):
        value=settings.validate({})
        self.assertEqual(value['fps'],60);self.assertTrue(value['limit_fps']);self.assertTrue(value['enabled'])

    def test_rejects_invalid_or_injected_values_before_rendering(self):
        for value in [{'fps':0},{'fps':True},{'fps':60.5},{'fps':'60'},{'mass':float('nan')},{'enabled':'yes'}, {'open_type':'zoom"; exec anything'}, {'unknown':True}]:
            with self.assertRaises(ValueError,msg=str(value)):settings.validate(value)

    def test_ftlabs_disables_each_event_without_overwriting_appearance(self):
        original=(BIN.parents[1]/'picom/picom-ftlabs.conf').read_text()
        text=settings.render(original,'ftlabs',{'open_enabled':False,'popup_type':'squeeze','fps':60})
        self.assertIn('animation-for-open-window = "none";',text)
        self.assertIn('animation-for-transient-window = "squeeze";',text)
        for line in original.splitlines():
            if 'class_g' in line or line.startswith(('shadow','corner-radius','inactive-opacity','opacity-rule')):self.assertIn(line,text)
        self.assertEqual(len(re.findall(r'^animations =',text,re.M)),1)

    def test_master_disable_removes_native_motion_and_fading(self):
        original=(BIN.parents[1]/'picom/picom-ftlabs.conf').read_text()
        text=settings.render(original,'ftlabs',{'enabled':False})
        self.assertIn('animations = false;',text);self.assertIn('fading = false;',text)

    def test_modern_popup_effect_and_security_exclusions_are_retained(self):
        original=(BIN.parents[1]/'picom/picom.conf').read_text()
        text=settings.render(original,'modern',{'popup_type':'slide-right','popup_ms':250})
        self.assertEqual(len(re.findall(r'^animations =',text,re.M)),1)
        self.assertEqual(len(re.findall(r'^rules =',text,re.M)),1)
        self.assertIn('duration = 0.25;',text);self.assertIn('direction = "right";',text)
        self.assertIn("class_g != 'i3lock'",text);self.assertIn("class_g != 'RiceMotion'",text)

    def test_unknown_modern_config_layout_is_never_silently_overwritten(self):
        with self.assertRaises(ValueError):settings.render('backend="glx";','modern',{})

    def test_generated_configs_are_immutable_and_fps_changes_get_new_paths(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(settings,'cache_dir',return_value=Path(directory)),patch.object(settings,'limiter_library',return_value=Path(directory)/'limit.so'):
            base=BIN.parents[1]/'picom/picom-ftlabs.conf'
            first,env=settings.prepare(base,{'fps':60});content=first.read_text()
            second,other_env=settings.prepare(base,{'fps':30})
            self.assertNotEqual(first,second);self.assertEqual(first.read_text(),content)
            self.assertEqual(env['RICE_PICOM_FPS'],'60');self.assertEqual(other_env['RICE_PICOM_FPS'],'30')
            self.assertIn('limit.so',env['LD_PRELOAD'])

class TransactionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.path=self.root/'config/animations.json';self.path.parent.mkdir();self.old=json.dumps({'fps':75})
        self.path.write_text(self.old);self.base=BIN.parents[1]/'picom/picom-ftlabs.conf';self.candidate=self.root/'candidate.conf';self.candidate.write_text('candidate')
        self.patches=[patch.object(settings,'settings_path',return_value=self.path),patch.dict(os.environ,{'XDG_STATE_HOME':str(self.root/'state')}),patch.object(settings,'detect',return_value={'engine':'ftlabs'}),patch.object(settings,'base_path',return_value=self.base),patch.object(settings,'prepare',return_value=(self.candidate,{}))]
        for item in self.patches:item.start()
    def tearDown(self):
        for item in reversed(self.patches):item.stop()
        self.temp.cleanup()

    def test_failed_compositor_activation_restores_previous_preferences(self):
        with patch.object(settings.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'','')),patch.object(settings,'restart',side_effect=[RuntimeError('Rejected activation'),None]) as restart:
            with self.assertRaisesRegex(RuntimeError,'Rejected activation'):settings.apply({'fps':30})
        self.assertEqual(self.path.read_text(),self.old);self.assertEqual(restart.call_count,2)
        saved=list((self.root/'state/rice/animation-backups').glob('*/settings.json'))
        self.assertEqual(saved[0].read_text(),self.old)

    def test_preflight_rejection_never_touches_saved_settings_or_running_compositor(self):
        with patch.object(settings.subprocess,'run',return_value=subprocess.CompletedProcess([],1,'','Invalid option')),patch.object(settings,'restart') as restart:
            with self.assertRaisesRegex(RuntimeError,'Picom rejected'):settings.apply({'fps':30})
        self.assertEqual(self.path.read_text(),self.old);restart.assert_not_called()

    def test_recovery_mode_blocks_compositor_mutations(self):
        (self.path.parent/'compositor-safe-mode').write_text('Emergency display recovery')
        with patch.object(settings,'restart') as restart:
            with self.assertRaisesRegex(RuntimeError,'recovery mode'):settings.apply({'fps':30})
        self.assertEqual(self.path.read_text(),self.old);restart.assert_not_called()

    def test_success_saves_backup_before_activation(self):
        with patch.object(settings.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'','')),patch.object(settings,'restart'):
            backup=settings.apply({'fps':60})
        self.assertEqual(json.loads(self.path.read_text())['fps'],60)
        self.assertEqual((backup/'settings.json').read_text(),self.old)
        self.assertEqual((backup/self.base.name).read_text(),self.base.read_text())

@unittest.skipUnless(shutil.which('cc'),'C compiler unavailable')
class FrameLimiterTests(unittest.TestCase):
    def test_caps_actual_presentation_and_survives_lazy_epoxy_dispatch(self):
        source='''#include <stdio.h>
#include <time.h>
static void driver(void *d,unsigned long w){(void)d;(void)w;}
static void resolve(void *d,unsigned long w);
void (*epoxy_glXSwapBuffers)(void *,unsigned long)=resolve;
static void resolve(void *d,unsigned long w){epoxy_glXSwapBuffers=driver;driver(d,w);}
int main(void){struct timespec a,b;clock_gettime(CLOCK_MONOTONIC,&a);for(int i=0;i<13;i++)epoxy_glXSwapBuffers(NULL,0);clock_gettime(CLOCK_MONOTONIC,&b);printf("%.6f",(b.tv_sec-a.tv_sec)+(b.tv_nsec-a.tv_nsec)/1e9);}
'''
        with tempfile.TemporaryDirectory() as directory,patch.object(settings,'cache_dir',return_value=Path(directory)):
            root=Path(directory);(root/'stub.c').write_text(source)
            subprocess.run(['cc','-rdynamic',str(root/'stub.c'),'-o',str(root/'stub')],check=True,capture_output=True)
            library=settings.limiter_library()
            for fps,minimum in [(60,.19),(30,.38)]:
                env={**os.environ,'RICE_PICOM_FPS':str(fps),'LD_PRELOAD':str(library)}
                elapsed=float(subprocess.check_output([str(root/'stub')],env=env,text=True))
                self.assertGreaterEqual(elapsed,minimum);self.assertLess(elapsed,2)

if __name__=='__main__':unittest.main()
