"""Reload recovery and signal-readiness regressions without touching live daemons."""
from pathlib import Path
import signal
import sys
import tempfile
import unittest
from unittest.mock import patch

BIN=Path(__file__).resolve().parents[1]/'stow/desktop/.config/rice/bin'
sys.path.insert(0,str(BIN))
import hotkeys

class HotkeyTests(unittest.TestCase):
    def test_reload_recovers_missing_main_daemon(self):
        processes=[]
        def started():processes.append((123,[]))
        with tempfile.TemporaryDirectory() as directory,patch.object(hotkeys,'runtime_directory',return_value=Path(directory)),patch.object(hotkeys,'main_processes',side_effect=lambda:list(processes)),patch.object(hotkeys,'start',side_effect=started) as start,patch.object(hotkeys.os,'kill') as kill:
            hotkeys.reload_bindings()
            start.assert_called_once();kill.assert_not_called()

    def test_signal_waits_for_handler_rearming(self):
        mask=1<<(signal.SIGUSR1-1)
        with tempfile.TemporaryDirectory() as directory,patch.object(hotkeys,'runtime_directory',return_value=Path(directory)),patch.object(hotkeys,'main_processes',return_value=[(123,[])]),patch.object(Path,'read_text',side_effect=['SigCgt:\t0\n',f'SigCgt:\t{mask:x}\n']),patch.object(hotkeys.time,'sleep') as sleep,patch.object(hotkeys.os,'kill') as kill:
            hotkeys.reload_bindings()
            sleep.assert_any_call(.005);kill.assert_called_once_with(123,signal.SIGUSR1)

    def test_consecutive_reload_calls_are_spaced(self):
        mask=1<<(signal.SIGUSR1-1)
        with tempfile.TemporaryDirectory() as directory,patch.object(hotkeys,'runtime_directory',return_value=Path(directory)),patch.object(hotkeys,'main_processes',return_value=[(123,[])]),patch.object(Path,'read_text',return_value=f'SigCgt:\t{mask:x}\n'),patch.object(hotkeys.time,'sleep') as sleep,patch.object(hotkeys.os,'kill') as kill:
            hotkeys.reload_bindings();hotkeys.reload_bindings()
            self.assertEqual(kill.call_count,2)
            self.assertTrue(any(.10<float(c.args[0])<=.15 for c in sleep.call_args_list))

if __name__=='__main__':unittest.main()
