"""Transitions preserve actions when optional rendering is unavailable."""
import importlib.util
from pathlib import Path
import runpy
import sys
import tempfile
from types import ModuleType,SimpleNamespace
import unittest
from unittest.mock import Mock,patch

BIN=Path(__file__).resolve().parents[1]/'stow/desktop/.config/rice/bin'
sys.path.insert(0,str(BIN))
import motion
import motion_client
import workspace_state
import power_backend

class MotionTests(unittest.TestCase):
    def test_easing_has_no_overshoot_and_finishes_at_target(self):
        values=[motion.easing(i/100) for i in range(101)]
        self.assertEqual(values[0],0);self.assertEqual(values[-1],1)
        self.assertEqual(values,sorted(values));self.assertTrue(all(0<=v<=1 for v in values))

    def test_rejects_shell_syntax_and_unbounded_desktop_selectors(self):
        for target in ['1; touch unexpected','$(anything)','focused','11','-1','']:
            with self.assertRaises(ValueError):motion.focus_command(target)
        self.assertEqual(motion.focus_command('next.local'),['bspc','desktop','-f','next.local'])
        self.assertEqual(motion.focus_command('3',True),['bspc','node','-d','3','--follow'])

    def test_missing_service_keeps_original_workspace_action(self):
        with patch.object(motion,'request',return_value=False),patch.object(motion.subprocess,'run') as run,patch.object(sys,'argv',['motion.py','--focus','4']):
            motion.main()
        run.assert_called_once_with(['bspc','desktop','-f','4'],check=True)

    def test_missing_socket_is_optional(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(motion_client,'socket_path',return_value=Path(directory)/'missing'):
            self.assertFalse(motion_client.request('prepare',window=1))

    def test_optional_kitty_import_failure_never_breaks_original_actions(self):
        handler=ModuleType('kittens.tui.handler');handler.result_handler=lambda **_:lambda callback:callback
        timer=ModuleType('kitty.fast_data_types');timer.add_timer=Mock()
        utils=ModuleType('kitty.utils') # old Kitty versions may lack platform_window_id
        modules={'kittens.tui.handler':handler,'kitty.fast_data_types':timer,'kitty.utils':utils}
        with patch.dict(sys.modules,modules):
            script=runpy.run_path(str(BIN.parents[1]/'kitty/kittens/animated_tabs.py'))
            boss=Mock()
            for name,method in [('new','new_tab_with_cwd'),('split','launch'),('next','next_tab'),('previous','previous_tab'),('forward','move_tab_forward'),('backward','move_tab_backward')]:
                script['handle_result'](['animated_tabs.py',name],None,1,boss)
                getattr(boss,method).assert_called_once();boss.reset_mock()
        timer.add_timer.assert_not_called()

class PowerBackendTests(unittest.TestCase):
    def test_cycle_respects_hardware_profile_list(self):
        self.assertEqual(power_backend.next_profile('balanced',['balanced','power-saver']),'power-saver')
        self.assertEqual(power_backend.next_profile('power-saver',['balanced','power-saver']),'balanced')
        self.assertEqual(power_backend.next_profile('balanced',['balanced','performance','power-saver']),'performance')
        with self.assertRaises(ValueError):power_backend.next_profile('balanced',[])

class WorkspaceTests(unittest.TestCase):
    def test_one_snapshot_retains_all_names_roles_icons_and_states(self):
        def desktop(n,root=None):return dict(id=n,name=str(n),root=root)
        tree=dict(focusedMonitorId=1,monitors=[dict(id=1,focusedDesktopId=1,desktops=[
            desktop(1),desktop(2,{'client':{'urgent':False}}),
            desktop(3,{'client':None,'firstChild':{'client':{'urgent':True}},'secondChild':None}),
            *[desktop(n) for n in range(4,11)]])])
        values=workspace_state.workspaces(tree)
        self.assertEqual([v['name'] for v in values],list(map(str,range(1,11))))
        self.assertEqual([v['state'] for v in values[:4]],['focused','occupied','urgent','free'])
        self.assertTrue(all(v['icon'] for v in values))
        lines=workspace_state.tint2(values,{'accent':'#ff0000'}).splitlines()
        self.assertEqual(len(lines),10);self.assertIn('#ff0000',lines[0])

if __name__=='__main__':unittest.main()
