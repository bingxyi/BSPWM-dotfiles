#!/usr/bin/env python3
"""Per-device libinput controls, restored at login and hotplug.

GUI (no arguments): live preview — drag and try the mouse.
--restore              reapply mouse.json at login
--watch                daemon: reapply on each hotplug event
--list                 dump devices as JSON
--set-speed <v>        set sensitivity for all mice and save
"""
import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

STATE = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))) / 'offsec/mouse.json'
# label, property, kind, lower, upper
CONTROLS = [
    ('Sensitivity', 'libinput Accel Speed', 'float', -1, 1),
    ('Acceleration profile', 'libinput Accel Profile Enabled', 'profile', 0, 0),
    ('Natural scrolling', 'libinput Natural Scrolling Enabled', 'bool', 0, 1),
    ('Left-handed mode', 'libinput Left Handed Enabled', 'bool', 0, 1),
    ('Middle button: left + right', 'libinput Middle Emulation Enabled', 'bool', 0, 1),
    ('Horizontal scrolling', 'libinput Horizontal Scroll Enabled', 'bool', 0, 1),
    ('Scroll distance (lower = faster)', 'libinput Scrolling Pixel Distance', 'int', 1, 100),
    ('High-resolution wheel', 'libinput High Resolution Wheel Scroll Enabled', 'bool', 0, 1),
]

# Sensitivity scale labels, from slowest to fastest.
SPEED_PRESETS = [
    ('Very slow', -0.60),
    ('Slow', -0.35),
    ('Comfortable', -0.15),
    ('Default', 0.00),
    ('Fast', 0.45),
]

ACCEL = 'libinput Accel Speed'
PROFILE = 'libinput Accel Profile Enabled'


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE, timeout=5).strip()


def properties(device):
    result = {}
    for line in run('xinput', 'list-props', str(device)).splitlines()[1:]:
        match = re.match(r'\s*(.+?) \(\d+\):\s*(.*)', line)
        if match:
            result[match[1]] = match[2].split(', ')
    return result


def devices():
    result = []
    for line in run('xinput', 'list', '--short').splitlines():
        match = re.search(r'↳\s*(.*?)\s+id=(\d+).*slave\s+pointer', line)
        if not match:
            continue
        name, identifier = match.groups()
        props = properties(identifier)
        if ACCEL not in props:
            continue
        key = name + '|' + ','.join(props.get('Device Product ID', []))
        result.append((identifier, name, key, props))
    return result


def load():
    if not STATE.exists():
        return {}
    data = json.loads(STATE.read_text())
    if not isinstance(data, dict):
        raise ValueError('Invalid format in mouse.json')
    return data


def save(data):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=STATE.parent, delete=False) as out:
        json.dump(data, out, indent=2)
        out.write('\n')
    os.replace(out.name, STATE)


def apply(device, values):
    """Apply values to the device, verify with the server, and roll back on failure."""
    identifier = device[0]
    props = properties(identifier)
    if not isinstance(values, dict):
        raise ValueError('Invalid mouse preferences')
    pending = {}
    for _, prop, kind, low, high in CONTROLS:
        if prop not in values or prop not in props:
            continue
        raw = values[prop]
        if not isinstance(raw, list):
            raise ValueError('Invalid value: ' + prop)
        if kind == 'profile':
            available = props.get('libinput Accel Profiles Available', [])
            if len(raw) != len(available) or sum(int(x) for x in raw) != 1:
                raise ValueError('Invalid profile')
            if any(str(v) not in ('0', '1') or (int(v) and available[i] != '1') for i, v in enumerate(raw)):
                raise ValueError('Unavailable profile')
        elif len(raw) != 1 or not low <= float(raw[0]) <= high:
            raise ValueError('Value out of range: ' + prop)
        elif kind in ('bool', 'int') and not float(raw[0]).is_integer():
            raise ValueError('Integer value expected: ' + prop)
        pending[prop] = list(map(str, raw))
    changed = []
    try:
        for prop, raw in pending.items():
            changed.append(prop)
            run('xinput', 'set-prop', identifier, prop, *raw)
        actual = properties(identifier)
        for prop, raw in pending.items():
            measured = actual.get(prop, [])
            if len(measured) != len(raw) or any(
                not math.isfinite(float(a)) or abs(float(a)-float(b)) > 0.0001
                for a, b in zip(measured, raw)
            ):
                raise RuntimeError('The driver did not apply: ' + prop)
    except (subprocess.SubprocessError, OSError, ValueError, RuntimeError) as error:
        failures = []
        for prop in reversed(changed):
            try:
                run('xinput', 'set-prop', identifier, prop, *props[prop])
            except (subprocess.SubprocessError, OSError):
                failures.append(prop)
        if failures:
            raise RuntimeError('Restore failed: ' + ', '.join(failures)) from error
        raise


def persist(device, values):
    """Salva values no mouse.json sob a chave do dispositivo."""
    data = load()
    data.setdefault(device[2], {}).update(values)
    save(data)


def restore():
    data = load()
    for device in devices():
        if device[2] in data:
            apply(device, data[device[2]])


def set_speed(value):
    """Command-line mode: apply the same sensitivity to every libinput mouse."""
    value = max(-1.0, min(1.0, float(value)))
    found = devices()
    if not found:
        raise SystemExit('No libinput mouse connected.')
    for device in found:
        values = {ACCEL: [round(value, 2)]}
        apply(device, values)
        persist(device, values)
        print(f'{device[1]}: sensitivity = {value:+.2f}')


def watch():
    lockpath = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp')) / f'offsec-mouse-{os.getuid()}.lock'
    with lockpath.open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        previous = set()
        while True:
            try:
                data = load()
                current = devices()
                keys = {(d[0], d[2]) for d in current}
                for device in current:
                    if (device[0], device[2]) not in previous and device[2] in data:
                        apply(device, data[device[2]])
                previous = keys
            except (subprocess.SubprocessError, OSError, ValueError) as error:
                print(error, flush=True)
            time.sleep(3)


def speed_label(value):
    """Return the nearest readable sensitivity label for the value."""
    name, _ = min(SPEED_PRESETS, key=lambda pair: abs(pair[1] - value))
    return name


CSS = b'''
.offsec-title  { font-size: 15px; font-weight: 700; }
.offsec-sub    { font-size: 11px; opacity: 0.62; }
.offsec-value  { font-size: 11px; opacity: 0.80; }
.offsec-status { font-size: 11px; opacity: 0.75; padding: 4px 0; }
.offsec-error  { font-size: 11px; color: #ea6962; padding: 4px 0; }
.offsec-card   { padding: 6px 2px; }
'''


def gui():
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk, GLib

    # WM_CLASS = "offsec-mouse", "OffsecMouse" matches the bspwm rule.
    # Set it here instead of using the deprecated set_wmclass().
    GLib.set_prgname('offsec-mouse')
    Gdk.set_program_class('OffsecMouse')

    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    window = Gtk.Window(title='Mouse · Preferences')
    window.set_default_size(620, 560)
    window.set_border_width(20)

    outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
    window.add(outer)

    heading = Gtk.Label(label='Mouse preferences', xalign=0)
    heading.get_style_context().add_class('offsec-title')
    outer.pack_start(heading, False, False, 0)

    subtitle = Gtk.Label(
        label='Changes apply immediately. Move the mouse to try them. "Save" keeps them for future logins.',
        xalign=0)
    subtitle.set_line_wrap(True)
    subtitle.get_style_context().add_class('offsec-sub')
    outer.pack_start(subtitle, False, False, 0)

    selector = Gtk.ComboBoxText()
    outer.pack_start(selector, False, False, 0)

    outer.pack_start(Gtk.Separator(), False, False, 2)

    scroller = Gtk.ScrolledWindow()
    scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    outer.pack_start(scroller, True, True, 0)
    grid = Gtk.Grid(column_spacing=20, row_spacing=12)
    grid.get_style_context().add_class('offsec-card')
    scroller.add(grid)

    status = Gtk.Label(label='', xalign=0)
    status.set_line_wrap(True)
    status.get_style_context().add_class('offsec-status')
    outer.pack_start(status, False, False, 0)

    buttons = Gtk.Box(spacing=8, homogeneous=True)
    outer.pack_start(buttons, False, False, 0)
    refresh = Gtk.Button(label='Refresh')
    defaults = Gtk.Button(label='Defaults')
    undo = Gtk.Button(label='Undo')
    commit = Gtk.Button(label='Save')
    commit.get_style_context().add_class('suggested-action')
    for button in (refresh, defaults, undo, commit):
        buttons.pack_start(button, True, True, 0)

    current, widgets = [], {}
    baseline = {}       # Device state at open/save time, used by Undo.
    guard = {'busy': False, 'timer': 0}

    def selected():
        index = selector.get_active()
        return current[index] if 0 <= index < len(current) else None

    def say(text, error=False):
        context = status.get_style_context()
        context.remove_class('offsec-error' if not error else 'offsec-status')
        context.add_class('offsec-error' if error else 'offsec-status')
        status.set_text(text)

    def collect():
        """Read the widgets and return a dictionary of libinput values."""
        device = selected()
        if device is None:
            return {}
        props = properties(device[0])
        values = {}
        for prop, (widget, kind) in widgets.items():
            if kind == 'bool':
                values[prop] = [int(widget.get_active())]
            elif kind == 'profile':
                index = int(widget.get_active_id())
                values[prop] = [int(i == index) for i in range(len(props[prop]))]
            else:
                values[prop] = [round(widget.get_value(), 2) if kind == 'float'
                                else int(widget.get_value())]
        return values

    def live(*_):
        """Apply live with debouncing so dragging the slider does not flood the server."""
        if guard['busy']:
            return
        if guard['timer']:
            GLib.source_remove(guard['timer'])
        guard['timer'] = GLib.timeout_add(90, live_commit)

    def live_commit():
        guard['timer'] = 0
        device = selected()
        if device is None:
            return False
        try:
            apply(device, collect())
            say('Applied, unsaved. Click Save to keep these settings.')
        except Exception as error:
            say('Could not apply: ' + str(error), error=True)
        return False

    def sync_labels():
        for prop, (widget, kind) in widgets.items():
            if kind == 'float' and prop == ACCEL:
                widget.set_tooltip_text(speed_label(widget.get_value()))

    def populate(*_):
        guard['busy'] = True
        for child in grid.get_children():
            grid.remove(child)
        widgets.clear()
        device = selected()
        for button in (commit, defaults, undo):
            button.set_sensitive(device is not None)
        if device is None:
            guard['busy'] = False
            return
        props = properties(device[0])
        row = 0
        for label, prop, kind, low, high in CONTROLS:
            if prop not in props:
                continue
            title = Gtk.Label(label=label, xalign=0)
            title.set_line_wrap(True)
            title.set_hexpand(True)
            grid.attach(title, 0, row, 1, 1)
            if kind == 'bool':
                widget = Gtk.Switch(active=props[prop][0] == '1')
                widget.set_halign(Gtk.Align.END)
                widget.set_valign(Gtk.Align.CENTER)
                widget.connect('notify::active', live)
            elif kind == 'profile':
                widget = Gtk.ComboBoxText()
                for index, supported in enumerate(props['libinput Accel Profiles Available']):
                    if supported == '1':
                        widget.append(str(index), [
                            'Adaptive (accelerates with movement)',
                            'Flat (1:1, no acceleration)',
                            'Custom'][index])
                widget.set_active_id(str(props[prop].index('1')))
                widget.connect('changed', live)
            else:
                widget = Gtk.Scale.new_with_range(
                    Gtk.Orientation.HORIZONTAL, low, high, .01 if kind == 'float' else 1)
                widget.set_digits(2 if kind == 'float' else 0)
                widget.set_value(float(props[prop][0]))
                widget.set_size_request(260, -1)
                widget.set_value_pos(Gtk.PositionType.RIGHT)
                if prop == ACCEL:
                    for name, mark in SPEED_PRESETS:
                        widget.add_mark(mark, Gtk.PositionType.BOTTOM, name)
                widget.connect('value-changed', live)
            widgets[prop] = (widget, kind)
            grid.attach(widget, 1, row, 1, 1)
            row += 1
        grid.show_all()
        sync_labels()
        guard['busy'] = False

    def snapshot():
        device = selected()
        if device is not None:
            baseline[device[2]] = collect()

    def on_device_changed(*_):
        populate()
        snapshot()

    def reload_devices(*_):
        try:
            current[:] = devices()
            selector.remove_all()
            for device in current:
                selector.append_text(device[1])
            selector.set_active(0 if current else -1)
            if not current:
                say('No libinput mouse connected.', error=True)
            else:
                say('')
        except Exception as error:
            say(str(error), error=True)

    def on_defaults(*_):
        device = selected()
        if device is None:
            return
        try:
            props = properties(device[0])
            values = {prop: props[prop + ' Default']
                      for prop in widgets if prop + ' Default' in props}
            apply(device, values)
            populate()
            say('Device defaults applied, unsaved.')
        except Exception as error:
            say('Could not apply defaults: ' + str(error), error=True)

    def on_undo(*_):
        device = selected()
        if device is None or device[2] not in baseline:
            return
        try:
            apply(device, baseline[device[2]])
            populate()
            say('Restored the settings from when this window opened.')
        except Exception as error:
            say('Could not undo: ' + str(error), error=True)

    def on_commit(*_):
        device = selected()
        if device is None:
            return
        try:
            values = collect()
            apply(device, values)
            persist(device, values)
            baseline[device[2]] = values
            say('Saved for future logins and mouse reconnections.')
        except Exception as error:
            say('Could not save: ' + str(error), error=True)

    selector.connect('changed', on_device_changed)
    refresh.connect('clicked', reload_devices)
    defaults.connect('clicked', on_defaults)
    undo.connect('clicked', on_undo)
    commit.connect('clicked', on_commit)
    window.connect('destroy', Gtk.main_quit)
    window.connect('key-press-event', lambda _w, event: (
        Gtk.main_quit() if event.keyval == Gdk.KEY_Escape else None))
    reload_devices()
    window.show_all()
    Gtk.main()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', action='store_true')
    parser.add_argument('--watch', action='store_true')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--set-speed', type=float, metavar='V',
                        help='sensitivity -1.0 (slow) .. 1.0 (fast)')
    args = parser.parse_args()
    if args.watch:
        watch()
    elif args.restore:
        restore()
    elif args.list:
        print(json.dumps(devices(), indent=2))
    elif args.set_speed is not None:
        set_speed(args.set_speed)
    else:
        gui()
