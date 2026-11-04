"""Feature behavior in private fixtures, never real pairing/binds/events."""
from datetime import date
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock,patch

BIN=Path(__file__).resolve().parents[1]/'stow/desktop/.config/rice/bin'
sys.path.insert(0,str(BIN))
from desktop_state import BindStore, EventStore, canonical_chord, reserved_chords
import calendar_state


class EventTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.path=Path(self.temp.name)/'events.json';self.store=EventStore(self.path)
    def tearDown(self):self.temp.cleanup()

    def test_add_edit_delete_and_reopen(self):
        event=self.store.save('Team review','2026-11-04','14:30','Bring notes')
        self.assertEqual(EventStore(self.path).all()[0]['title'],'Team review')
        updated=self.store.save('Team review updated','2026-11-05','15:00','',event['id'])
        self.assertEqual(len(self.store.all()),1)
        self.assertEqual(updated['id'],event['id'])
        self.store.delete(event['id']);self.assertEqual(self.store.all(),[])

    def test_dots_and_today_are_independent_and_correct(self):
        self.store.save('A','2026-11-12');self.store.save('B','2026-11-12','12:00')
        value=self.store.month(2026,11,today=date(2026,11,4))
        days={d['date']:d for week in value['weeks'] for d in week['days'] if d['date']}
        self.assertTrue(days['2026-11-04']['today']);self.assertFalse(days['2026-11-04']['marked'])
        self.assertEqual(days['2026-11-12']['count'],2);self.assertTrue(days['2026-11-12']['marked'])
        self.assertEqual(sum(d['today'] for d in days.values()),1)

    def test_leap_month_has_all_real_days_and_seven_cells_per_week(self):
        value=self.store.month(2028,2,today=date(2028,2,29))
        self.assertEqual(sum(bool(d['date']) for w in value['weeks'] for d in w['days']),29)
        self.assertTrue(all(len(w['days'])==7 for w in value['weeks']))

    def test_invalid_event_or_corrupt_file_never_overwrites_data(self):
        for title,day,time in [('', '2026-11-04',''),('a','2026-02-30',''),('a','2026-11-04','25:00')]:
            with self.assertRaises(ValueError):self.store.save(title,day,time)
        self.path.write_text('invalid JSON')
        with self.assertRaises(ValueError):self.store.save('x','2026-11-04')
        self.assertEqual(self.path.read_text(),'invalid JSON')


class BindTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.config=Path(self.temp.name)
        self.store=BindStore(self.config);self.store.base.parent.mkdir(parents=True)
        self.store.base.write_text('super + {d,shift + n}\n\ttrue\n')
    def tearDown(self):self.temp.cleanup()

    def test_super_is_required_even_without_gui(self):
        for chord in ['ctrl + k','alt + F1','super','super + shift','Super_L']:
            with self.assertRaises(ValueError):self.store.save(chord,'terminal')
        self.assertFalse(self.store.path.exists())

    def test_reserved_expanded_bind_is_rejected(self):
        for chord in ['super + d','shift + super + n']:
            with self.assertRaisesRegex(ValueError,'built-in'):self.store.save(chord,'terminal')

    def test_save_edit_delete_generates_valid_separate_config(self):
        original=self.store.base.read_text()
        item=self.store.save('shift + super + F7','terminal')
        self.assertIn('super + shift + F7\n\tkitty',self.store.rendered.read_text())
        self.store.save('super + F8','browser',item['id'])
        self.assertEqual(len(self.store.all()),1);self.assertNotIn('F7',self.store.rendered.read_text())
        self.assertEqual(self.store.base.read_text(),original)
        self.store.delete(item['id']);self.assertEqual(self.store.all(),[])
        self.assertNotIn('F8',self.store.rendered.read_text())

    def test_duplicate_is_rejected_and_unknown_action_cannot_inject_command(self):
        self.store.save('super + F7','terminal')
        with self.assertRaises(ValueError):self.store.save('super + F7','browser')
        with self.assertRaises(ValueError):self.store.save('super + F8','terminal\nmalicious')


try:
    import desktop_ui
except ImportError:
    desktop_ui=None


@unittest.skipIf(desktop_ui is None,'GTK bindings unavailable')
class UIWiringTests(unittest.TestCase):
    def test_live_capture_tracks_super_shift_and_key_without_launching_action(self):
        ui=desktop_ui;fake=SimpleNamespace(capturing=True,capture=Mock(),status=Mock(),chord='',error=Mock())
        e=SimpleNamespace(keyval=ui.Gdk.KEY_k,state=ui.Gdk.ModifierType.SUPER_MASK|ui.Gdk.ModifierType.SHIFT_MASK)
        self.assertTrue(ui.BindWindow.key(fake,None,e))
        self.assertEqual(fake.chord,'super + shift + k')
        fake.capture.set_label.assert_called_with('super + shift + k')
        e.state=ui.Gdk.ModifierType.CONTROL_MASK;ui.BindWindow.key(fake,None,e)
        self.assertEqual(fake.chord,'');fake.error.assert_called()

    def test_modifier_release_updates_current_pressed_keys(self):
        ui=desktop_ui;fake=SimpleNamespace(capturing=True,capture=Mock(),release=Mock(),hint=Mock())
        event=SimpleNamespace(keyval=ui.Gdk.KEY_Shift_L,state=ui.Gdk.ModifierType.SUPER_MASK|ui.Gdk.ModifierType.SHIFT_MASK)
        ui.BindWindow.key_release(fake,None,event)
        fake.capture.set_label.assert_called_with('SUPER')
        fake.release.assert_not_called()

    def test_forget_calls_bluez_remove_device_only_after_confirmation(self):
        ui=desktop_ui;device=Mock();device.get_object_path.return_value='/org/bluez/hci0/dev_fixture'
        fake=SimpleNamespace(adapter=Mock(),prop=lambda *_:'Fixture headset',call=Mock())
        with patch.object(ui,'confirm',return_value=False):ui.BluetoothWindow.forget(fake,device)
        fake.call.assert_not_called()
        with patch.object(ui,'confirm',return_value=True):ui.BluetoothWindow.forget(fake,device)
        args=fake.call.call_args.args
        self.assertEqual(args[1],'RemoveDevice');self.assertEqual(args[2].unpack(),('/org/bluez/hci0/dev_fixture',))

    def test_refreshing_power_property_never_writes_back_to_adapter(self):
        fake=SimpleNamespace(updating=True)
        self.assertFalse(desktop_ui.BluetoothWindow.set_power(fake,None,True))


if __name__=='__main__':unittest.main()
