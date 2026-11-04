#!/usr/bin/env python3
"""Native RandR layouts and lossless bspwm desktop moves; no third-party Python packages."""
import argparse
import ctypes
import ctypes.util
import fcntl
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import time


HERE = Path(__file__).resolve().parent


def run(*args):
    return subprocess.check_output(args, text=True, timeout=10,
                                   env={**os.environ, 'LC_ALL': 'C'})


def parse_outputs(text):
    outputs = []
    current = None
    for line in text.splitlines():
        header = re.match(r'^(\S+) (connected|disconnected)\b(.*)', line)
        if header:
            name, status, tail = header.groups()
            geometry = re.search(r'(\d+)x(\d+)([+-]\d+)([+-]\d+)', tail)
            rotation = re.search(r'\b(normal|left|right|inverted)\s*$', tail.split('(')[0])
            current = dict(name=name, connected=status == 'connected',
                           primary=' primary ' in ' ' + tail + ' ', modes=[],
                           rotation=rotation.group(1) if rotation else 'normal',
                           geometry=tuple(map(int, geometry.groups())) if geometry else None)
            outputs.append(current)
        elif current and current['connected']:
            mode = re.match(r'^\s+(\d+x\d+)\s+(.+)', line)
            if mode:
                rates = re.findall(r'(\d+(?:\.\d+)?)([+*]*)', mode[2])
                current['modes'].append(dict(name=mode[1], rates=rates,
                                            preferred=any('+' in flags for _, flags in rates)))
    return outputs


def lid_closed():
    return any('closed' in p.read_text().lower()
               for p in Path('/proc/acpi/button/lid').glob('*/state'))


def selected_outputs(outputs, env=None, closed=False):
    env = os.environ if env is None else env
    chosen = [o for o in outputs if o['connected']]
    external = [o for o in chosen if not re.match(r'^(eDP|LVDS|DSI)', o['name'])]
    if closed and external:
        chosen = external
    if not chosen:
        raise RuntimeError('No connected output; current display configuration was left untouched')
    requested = env.get('RICE_MONITOR_PRIMARY', '')
    primary = next((o for o in chosen if o['name'] == requested), None)
    primary = primary or next((o for o in chosen if o['primary']), chosen[0])
    order = env.get('RICE_MONITOR_ORDER', '').split()
    rest = sorted((o for o in chosen if o is not primary),
                  key=lambda o: (order.index(o['name']) if o['name'] in order else len(order),
                                 o['geometry'][2:] if o['geometry'] else (0, 0), o['name']))
    return [primary, *rest]


def native_mode(output):
    modes = output['modes']
    if not modes:
        return None, None
    mode = next((m for m in modes if m['preferred']), modes[0])
    rate = max((r for r, _ in mode['rates']), key=float, default=None)
    return mode['name'], rate


def layout_command(outputs, chosen, safe=False, env=None):
    env = os.environ if env is None else env
    strategy = env.get("RICE_MONITOR_LAYOUT", "preserve")
    if strategy not in ("preserve", "ordered"):
        raise RuntimeError("RICE_MONITOR_LAYOUT must be preserve or ordered")
    preference = env.get("RICE_MONITOR_ORDER", "").split()
    arranged = sorted(chosen, key=lambda o: preference.index(o["name"])
                      if o["name"] in preference else len(preference)) if strategy == "ordered" else chosen
    args = ['xrandr']
    # Preserve an existing complete layout (portrait, stacked or mirrored) when
    # its active resolutions already match each output's preferred mode.
    keep_positions = strategy == 'preserve' and all(o['geometry'] for o in chosen)
    for o in chosen:
        mode, _ = native_mode(o)
        if mode:
            width, height = map(int, mode.split('x'))
            if o['rotation'] in ('left', 'right'):
                width, height = height, width
            keep_positions &= o['geometry'] is not None and o['geometry'][:2] == (width, height)
    previous = None
    for output in arranged:
        mode, rate = native_mode(output)
        args += ['--output', output['name']]
        if safe or not mode:
            args += ['--auto']
        else:
            args += ['--mode', mode]
            if rate:
                args += ['--rate', rate]
        rotation = output['rotation'] if output['geometry'] else 'normal'
        args += ['--rotate', rotation]
        if output is chosen[0]:
            args += ['--primary']
        if keep_positions and len(chosen) > 1:
            args += ['--pos', f"{output['geometry'][2]}x{output['geometry'][3]}"]
        elif previous:
            args += ['--right-of', previous]
        else:
            args += ['--pos', '0x0']
        previous = output['name']
    active_names = {o['name'] for o in chosen}
    for output in outputs:
        if output['name'] not in active_names and output['geometry']:
            args += ['--output', output['name'], '--off']
    return args


def state():
    return json.loads(run('bspc', 'wm', '--dump-state'))


def desktop_targets(names):
    # Preserve the upstream 1–6 / 7–10 workflow; additional screens share 7–10.
    return {str(n): names[0] if len(names) == 1 or n <= 6
            else names[1 + (n - 7) % (len(names) - 1)] for n in range(1, 11)}


def reconcile_desktops(names):
    original = state()
    focused = next((d['id'] for m in original['monitors'] for d in m['desktops']
                    if m['id'] == original.get('focusedMonitorId') and
                    d['id'] == m.get('focusedDesktopId')), None)
    # Retain disconnected monitor objects until all their desktops have moved.
    run('bspc', 'config', 'remove_unplugged_monitors', 'false')
    run('bspc', 'config', 'remove_disabled_monitors', 'false')
    targets = desktop_targets(names)
    desktops = {d['name']: (m['name'], d['id']) for m in original['monitors']
                for d in m['desktops']}
    for number, monitor in targets.items():
        if number not in desktops:
            run('bspc', 'monitor', monitor, '-a', number)
        elif desktops[number][0] != monitor:
            run('bspc', 'desktop', hex(desktops[number][1]), '-m', monitor)
    # Move personal desktops too, never reset names or drop windows on unplug.
    for monitor in state()['monitors']:
        if monitor['name'] not in names:
            for desktop in monitor['desktops']:
                run('bspc', 'desktop', hex(desktop['id']), '-m', names[0])
            # bspwm may create an empty fallback desktop on the old output.
            run('bspc', 'monitor', monitor['name'], '-r')
    for monitor in state()['monitors']:
        if monitor['name'] not in names:
            continue
        desktops = monitor['desktops']
        # Drop only empty auto-created placeholders, never named workspaces.
        removable = [d for d in desktops if d['name'] == 'Desktop' and not d.get('root')]
        for desktop in removable:
            if len(desktops) > 1:
                run('bspc', 'desktop', hex(desktop['id']), '-r')
                desktops = [d for d in desktops if d['id'] != desktop['id']]
        if not desktops:
            run('bspc', 'monitor', monitor['name'], '-a', 'extra-' + monitor['name'])
        else:
            ordered = sorted(desktops, key=lambda d: (int(d['name']) if d['name'].isdigit() else 100,
                                                       d['name']))
            run('bspc', 'monitor', monitor['name'], '-o', *[hex(d['id']) for d in ordered])
    run('bspc', 'wm', '-O', *names)
    remaining = {d['id'] for m in state()['monitors'] for d in m['desktops']}
    if focused in remaining:
        run('bspc', 'desktop', '-f', hex(focused))


def apply_layout(outputs=None, refresh=False):
    outputs = outputs if outputs is not None else parse_outputs(run('xrandr', '--query'))
    selected_outputs(outputs, closed=lid_closed())  # Validate before any mutation.
    # Set before RandR events, so bspwm does not discard disconnected desktops.
    run('bspc', 'config', 'remove_unplugged_monitors', 'false')
    run('bspc', 'config', 'remove_disabled_monitors', 'false')
    profile = False
    if shutil.which('autorandr') and os.environ.get('RICE_MONITOR_LAYOUT', 'preserve') != 'ordered':
        try:
            if run('autorandr', '--detected').strip():
                run('autorandr', '--change')
                outputs = parse_outputs(run('xrandr', '--query'))
                profile = any(o['geometry'] and o['connected'] for o in outputs)
        except subprocess.CalledProcessError:
            pass  # No usable saved profile: automatic portable layout.
    chosen = selected_outputs([o for o in outputs if o['geometry']] if profile else outputs,
                              env={} if profile else None, closed=lid_closed())
    if not profile:
        args = layout_command(outputs, chosen)
        try:
            run(*args)
        except subprocess.CalledProcessError:
            # Some GPU/dock combinations cannot drive the highest rates together.
            # Keep all connected screens, retry using the driver's safe rate.
            run(*layout_command(outputs, chosen, safe=True))
    deadline = time.monotonic() + 4
    names = [o['name'] for o in chosen]
    while not set(names) <= {m['name'] for m in state()['monitors']}:
        if time.monotonic() >= deadline:
            raise RuntimeError('bspwm has not detected the connected outputs; desktops were retained')
        time.sleep(.1)
    reconcile_desktops(names)
    run(sys.executable, str(HERE / 'monitor-sync.py'))
    if refresh:
        for script, flag in [('bar.sh', '--restart'), ('wallpaper.sh', '--restore')]:
            subprocess.Popen(['bash', str(HERE / script), flag], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
    return names


class RandREvents:
    """Sleep on native RandR events instead of constantly spawning xrandr."""
    def __init__(self):
        self.x = ctypes.CDLL(ctypes.util.find_library('X11'))
        self.rr = ctypes.CDLL(ctypes.util.find_library('Xrandr'))
        self.x.XOpenDisplay.argtypes = [ctypes.c_char_p]
        self.x.XOpenDisplay.restype = ctypes.c_void_p
        self.display = self.x.XOpenDisplay(None)
        if not self.display:
            raise RuntimeError('Cannot open X display')
        for name in ('XDefaultRootWindow', 'XConnectionNumber', 'XPending', 'XFlush', 'XCloseDisplay'):
            getattr(self.x, name).argtypes = [ctypes.c_void_p]
        self.x.XDefaultRootWindow.restype = ctypes.c_ulong
        self.x.XNextEvent.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        self.rr.XRRQueryExtension.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
        event, error = ctypes.c_int(), ctypes.c_int()
        if not self.rr.XRRQueryExtension(self.display, ctypes.byref(event), ctypes.byref(error)):
            raise RuntimeError('RandR extension unavailable')
        self.rr.XRRSelectInput.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int]
        self.rr.XRRSelectInput(self.display, self.x.XDefaultRootWindow(self.display), 1 | 2 | 4)
        self.x.XFlush(self.display)
        self.fd = self.x.XConnectionNumber(self.display)

    def wait(self):
        # A periodic safety check also handles lid changes without RandR events.
        if not self.x.XPending(self.display):
            select.select([self.fd], [], [], 15)
        event = (ctypes.c_long * 24)()
        while self.x.XPending(self.display):
            self.x.XNextEvent(self.display, ctypes.byref(event))

    def close(self):
        self.x.XCloseDisplay(self.display)


def runtime_directory():
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', f'/tmp/rice-{os.getuid()}'))
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    return runtime


def locked_apply(outputs=None, refresh=False):
    with (runtime_directory() / 'rice-monitor-apply.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return apply_layout(outputs, refresh)


def signature(outputs):
    return [(o['name'], o['connected'], o['modes']) for o in outputs], lid_closed()


def watch():
    runtime = runtime_directory()
    with (runtime / 'rice-monitors.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        events = RandREvents()
        previous = None
        while True:
            outputs = parse_outputs(run('xrandr', '--query'))
            current = signature(outputs)
            if current != previous:
                try:
                    locked_apply(outputs, refresh=previous is not None)
                    # Rates flagged current may change as a result of applying.
                    previous = signature(parse_outputs(run('xrandr', '--query')))
                except (RuntimeError, subprocess.SubprocessError) as error:
                    print(f'monitors: {error}', file=sys.stderr, flush=True)
            events.wait()
            time.sleep(.4)  # Debounce multiple connector events from one cable.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--plan', action='store_true', help='print display commands without applying them')
    parser.add_argument('--watch', action='store_true', help='follow HDMI/DP and lid changes using RandR events')
    args = parser.parse_args()
    if args.watch:
        watch()
    elif args.plan:
        outputs = parse_outputs(run('xrandr', '--query'))
        print(json.dumps(layout_command(outputs, selected_outputs(outputs, closed=lid_closed())), indent=2))
    else:
        locked_apply()


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'monitors: {error}', file=sys.stderr)
        sys.exit(1)
