"""Simulated RandR and bspwm scenarios: no real display or processes are modified."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('monitors', ROOT / 'stow/desktop/.config/rice/bin/monitor-layout.py')
monitors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitors)

LAPTOP = '''eDP-1 connected primary 1920x1080+1920+0 (normal left inverted right x axis y axis)
   1920x1080 120.21*+ 59.97
   1280x720 60.00
HDMI-1 connected 1920x1080+0+0 (normal left inverted right x axis y axis)
   1920x1080 60.00*+ 50.00
'''


class LayoutTests(unittest.TestCase):
    def test_explicit_physical_order_fixes_reversed_existing_geometry(self):
        text = LAPTOP.replace('1920x1080+1920+0', '1920x1080+TEMP+0').replace('1920x1080+0+0', '1920x1080+1920+0').replace('+TEMP+0', '+0+0')
        outputs = monitors.parse_outputs(text)
        env = {'RICE_MONITOR_LAYOUT': 'ordered', 'RICE_MONITOR_ORDER': 'HDMI-1 eDP-1'}
        chosen = monitors.selected_outputs(outputs, env)
        command = monitors.layout_command(outputs, chosen, env=env)
        # The primary output is eDP in this fixture, but physical order is independent.
        self.assertEqual(chosen[0]['name'], 'eDP-1')
        self.assertEqual(command[command.index('--output') + 1], 'HDMI-1')
        self.assertEqual(command[command.index('--pos') + 1], '0x0')
        self.assertEqual(command[command.index('--right-of') + 1], 'HDMI-1')
        self.assertIn('120.21', command)

    def test_explicit_order_tolerates_missing_preferred_hdmi(self):
        outputs = monitors.parse_outputs(LAPTOP.split('HDMI-1 connected')[0])
        env = {'RICE_MONITOR_LAYOUT': 'ordered', 'RICE_MONITOR_ORDER': 'HDMI-1 eDP-1'}
        command = monitors.layout_command(outputs, monitors.selected_outputs(outputs, env), env=env)
        self.assertEqual(command.count('--output'), 1)
        self.assertNotIn('HDMI-1', command)
        self.assertEqual(command[command.index('--pos') + 1], '0x0')

    def test_invalid_physical_layout_is_rejected(self):
        outputs = monitors.parse_outputs(LAPTOP)
        with self.assertRaisesRegex(RuntimeError, 'RICE_MONITOR_LAYOUT'):
            monitors.layout_command(outputs, outputs, env={'RICE_MONITOR_LAYOUT': 'typo'})

    def test_notebook_preserves_positions_and_supported_refresh(self):
        outputs = monitors.parse_outputs(LAPTOP)
        chosen = monitors.selected_outputs(outputs, {'RICE_MONITOR_PRIMARY': 'HDMI-1'})
        command = monitors.layout_command(outputs, chosen)
        self.assertEqual(chosen[0]['name'], 'HDMI-1')
        self.assertEqual(command.count('--output'), 2)
        self.assertIn('120.21', command)
        self.assertEqual(command[command.index('--pos') + 1], '0x0')
        self.assertIn('1920x0', command)
        self.assertNotIn('--off', command)

    def test_single_laptop_when_preferred_hdmi_is_unplugged(self):
        outputs = monitors.parse_outputs(LAPTOP.split('HDMI-1 connected')[0] + 'HDMI-1 disconnected\n')
        chosen = monitors.selected_outputs(outputs, {'RICE_MONITOR_PRIMARY': 'HDMI-1'})
        command = monitors.layout_command(outputs, chosen)
        self.assertEqual(len(chosen), 1)
        self.assertEqual(chosen[0]['name'], 'eDP-1')
        self.assertEqual(command[command.index('--pos') + 1], '0x0')
        self.assertEqual(set(monitors.desktop_targets(['eDP-1']).values()), {'eDP-1'})

    def test_new_hdmi_and_three_more_monitors_all_enabled(self):
        text = LAPTOP.split('HDMI-1 connected')[0]
        for name in ('HDMI-1', 'DP-2', 'DP-3', 'DP-4'):
            text += f'{name} connected\n   2560x1440 144.00+ 60.00\n'
        outputs = monitors.parse_outputs(text)
        chosen = monitors.selected_outputs(outputs, {})
        command = monitors.layout_command(outputs, chosen)
        self.assertEqual(command.count('--output'), 5)
        self.assertEqual(command.count('--right-of'), 4)
        self.assertNotIn('--off', command)
        targets = monitors.desktop_targets([o['name'] for o in chosen])
        self.assertEqual(set(targets), {str(i) for i in range(1, 11)})
        self.assertEqual(len(set(targets.values())), 5)

    def test_portrait_and_negative_positions_are_preserved(self):
        text = '''DP-1 connected primary 2560x1440+0+0 (normal left inverted right x axis y axis)
   2560x1440 60.0*+
DP-2 connected 1080x1920-1080-240 left (normal left inverted right x axis y axis)
   1920x1080 60.0*+
'''
        outputs = monitors.parse_outputs(text)
        command = monitors.layout_command(outputs, monitors.selected_outputs(outputs, {}))
        self.assertIn('-1080x-240', command)
        self.assertEqual(command[command.index('DP-2') + 5], '--rotate')
        self.assertIn('left', command)

    def test_property_lines_are_not_treated_as_modes(self):
        text = 'Virtual-1 connected\n\tEDID:\n\t\t00ffffffff00\n   1366x768 60.00+\n'
        output = monitors.parse_outputs(text)[0]
        self.assertEqual(monitors.native_mode(output), ('1366x768', '60.00'))

    def test_no_output_does_not_change_bspwm(self):
        with patch.object(monitors, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'No connected'):
                monitors.apply_layout(monitors.parse_outputs('HDMI-1 disconnected\n'))
            run.assert_not_called()

    def test_closed_lid_keeps_external_screen_and_open_lid_keeps_both(self):
        outputs = monitors.parse_outputs(LAPTOP)
        self.assertEqual([o['name'] for o in monitors.selected_outputs(outputs, {}, closed=True)], ['HDMI-1'])
        self.assertEqual(len(monitors.selected_outputs(outputs, {}, closed=False)), 2)

    def test_bandwidth_failure_retries_driver_safe_rates(self):
        calls = []
        def run(*args):
            calls.append(args)
            if args[0] == 'xrandr' and '--rate' in args:
                raise subprocess.CalledProcessError(1, args)
            return ''
        with patch.object(monitors, 'run', side_effect=run), patch.object(monitors.shutil, 'which', return_value=None), \
             patch.object(monitors, 'state', return_value={'monitors': [{'name': 'eDP-1'}, {'name': 'HDMI-1'}]}), \
             patch.object(monitors, 'reconcile_desktops'):
            monitors.apply_layout(monitors.parse_outputs(LAPTOP))
        display_calls = [c for c in calls if c[0] == 'xrandr']
        self.assertEqual(len(display_calls), 2)
        self.assertIn('--auto', display_calls[-1])
        self.assertNotIn('--rate', display_calls[-1])
        self.assertNotIn('--off', display_calls[-1])

    def test_saved_profile_is_applied_only_when_detected(self):
        calls = []
        def run(*args):
            calls.append(args)
            if args == ('autorandr', '--detected'):
                return 'work\n'
            if args == ('xrandr', '--query'):
                return LAPTOP
            return ''
        with patch.object(monitors, 'run', side_effect=run), patch.object(monitors.shutil, 'which', return_value='/usr/bin/autorandr'), \
             patch.object(monitors, 'state', return_value={'monitors': [{'name': 'eDP-1'}, {'name': 'HDMI-1'}]}), \
             patch.object(monitors, 'reconcile_desktops'):
            monitors.apply_layout(monitors.parse_outputs(LAPTOP))
        self.assertIn(('autorandr', '--change'), calls)
        self.assertFalse(any(c[0] == 'xrandr' and '--output' in c for c in calls))


class WorkspaceTests(unittest.TestCase):
    def setUp(self):
        self.next_id = 100
        self.model = {'focusedMonitorId': 1, 'monitors': [
            {'id': 1, 'name': 'HDMI-1', 'focusedDesktopId': 10,
             'desktops': [{'id': n + 9, 'name': str(n), 'root': {'client': n}} for n in range(1, 7)]},
            {'id': 2, 'name': 'eDP-1', 'focusedDesktopId': 16,
             'desktops': [{'id': n + 9, 'name': str(n), 'root': {'client': n}} for n in range(7, 11)]}]}
        self.original = copy.deepcopy(self.model)
        self.calls = []

    def fake_run(self, *args):
        self.calls.append(args)
        self.assertEqual(args[0], 'bspc')
        if args[1:3] == ('wm', '--dump-state'):
            return json.dumps(self.model)
        if args[1] == 'config':
            return ''
        if args[1:3] == ('wm', '-O'):
            self.model['monitors'].sort(key=lambda m: args[3:].index(m['name']))
        elif args[1] == 'monitor':
            monitor = next(m for m in self.model['monitors'] if m['name'] == args[2])
            if args[3] == '-a':
                self.next_id += 1
                monitor['desktops'].append({'id': self.next_id, 'name': args[4], 'root': None})
            elif args[3] == '-r':
                self.assertFalse(any(d['root'] for d in monitor['desktops']), 'would discard windows')
                self.model['monitors'].remove(monitor)
            elif args[3] == '-o':
                monitor['desktops'].sort(key=lambda d: args[4:].index(hex(d['id'])))
        elif args[1] == 'desktop' and args[2] != '-f':
            old = next(m for m in self.model['monitors'] if any(d['id'] == int(args[2], 16) for d in m['desktops']))
            desktop = next(d for d in old['desktops'] if d['id'] == int(args[2], 16))
            old['desktops'].remove(desktop)
            if args[3] == '-m':
                new = next(m for m in self.model['monitors'] if m['name'] == args[4])
                new['desktops'].append(desktop)
                if not old['desktops']:
                    self.next_id += 1
                    old['desktops'].append({'id': self.next_id, 'name': 'Desktop', 'root': None})
            else:
                self.assertIsNone(desktop['root'])
        return ''

    def desktops(self):
        return {d['name']: (m['name'], d['id'], d['root']) for m in self.model['monitors'] for d in m['desktops']}

    def test_unplug_preserves_every_workspace_window_and_custom_desktop(self):
        self.model['monitors'][0]['desktops'].append({'id': 88, 'name': 'personal', 'root': {'client': 88}})
        with patch.object(monitors, 'run', side_effect=self.fake_run):
            monitors.reconcile_desktops(['eDP-1'])
        desktops = self.desktops()
        self.assertEqual(set(desktops), {str(n) for n in range(1, 11)} | {'personal'})
        for n in range(1, 11):
            self.assertEqual(desktops[str(n)], ('eDP-1', n + 9, {'client': n}))
        self.assertEqual(desktops['personal'][2], {'client': 88})

    def test_replug_and_repeat_preserve_ids_windows_and_six_four_workflow(self):
        with patch.object(monitors, 'run', side_effect=self.fake_run):
            monitors.reconcile_desktops(['eDP-1'])
            self.model['monitors'].append({'id': 3, 'name': 'HDMI-1', 'desktops': [
                {'id': 200, 'name': 'Desktop', 'root': None}]})
            monitors.reconcile_desktops(['HDMI-1', 'eDP-1'])
            after = copy.deepcopy(self.desktops())
            monitors.reconcile_desktops(['HDMI-1', 'eDP-1'])
        self.assertEqual(self.desktops(), after)
        for n in range(1, 11):
            self.assertEqual(after[str(n)], ('HDMI-1' if n <= 6 else 'eDP-1', n + 9, {'client': n}))


if __name__ == '__main__':
    unittest.main()
