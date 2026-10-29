#!/usr/bin/env python3
"""Reconcile bspwm padding/order after RandR has restored the monitor layout."""
import json
import os
from pathlib import Path
import re
import subprocess
import time


def command(*args):
    return subprocess.check_output(args, text=True, timeout=3)


def synchronize():
    active = {}
    primary = None
    for line in command('xrandr', '--query').splitlines():
        match = re.match(r'^(\S+) connected( primary)? (\d+)x(\d+)([+-]\d+)([+-]\d+)', line)
        if match:
            name, chosen, width, height, x, y = match.groups()
            active[name] = dict(x=int(x), y=int(y), width=int(width), height=int(height))
            if chosen:
                primary = name
    if not active:
        raise RuntimeError('No active RandR monitor; padding was not changed')
    preferred = os.environ.get('OFFSEC_BAR_MONITOR', primary)
    primary = preferred if preferred in active else primary or next(iter(active))
    # Wait on actual rectangles, not an assumed fixed delay after xrandr.
    deadline = time.monotonic() + 3
    while True:
        state = json.loads(command('bspc', 'wm', '--dump-state'))
        monitors = {monitor['name']: monitor for monitor in state['monitors']}
        if all(name in monitors and monitors[name]['rectangle'] == rect for name, rect in active.items()):
            break
        if time.monotonic() >= deadline:
            raise RuntimeError('bspwm did not converge to the restored RandR rectangles')
        time.sleep(.05)
    profile_path = Path.home() / '.config/offsec/profile'
    profile = profile_path.read_text().strip() if profile_path.exists() else 'nyx'
    width = os.environ.get('OFFSEC_BAR_WIDTH', '54' if profile == 'vesper' else '46')
    if not width.isdigit() or not 1 <= int(width) <= 200:
        raise ValueError('Invalid sidebar width')
    subprocess.run(['bspc', 'wm', '-O', primary] + [name for name in monitors if name != primary], check=True)
    # Disabled monitors retain bspwm objects. Root shrinking can bake clipping
    # into padding (e.g. bottom=840 on a 1920-high portrait output).
    for name in monitors:
        for side in ('top', 'right', 'bottom', 'left'):
            value = width if name == primary and side == 'left' else '0'
            subprocess.run(['bspc', 'config', '-m', name, side + '_padding', value], check=True)
    # Preserve mouse input as well as stacking below fullscreen clients.
    subprocess.run([str(Path.home() / '.config/offsec/bin/restack-tint2.sh')], check=True)


if __name__ == '__main__':
    synchronize()
