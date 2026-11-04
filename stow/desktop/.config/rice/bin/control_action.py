#!/usr/bin/env python3
"""Finite control-center actions with serialization, deadlines and visible failures."""
import argparse
import datetime
import fcntl
import os
from pathlib import Path
import subprocess
import sys

# Use the existing user runtime for the same Eww socket as session helpers.
if not os.environ.get("XDG_RUNTIME_DIR"):
    runtime = Path(f"/run/user/{os.getuid()}")
    if runtime.is_dir() and runtime.stat().st_uid == os.getuid():
        os.environ["XDG_RUNTIME_DIR"] = str(runtime)
HERE=Path(__file__).resolve().parent
TOGGLES={
    'wifi':('network.sh','--wifi-toggle'),
    'dnd':('notifications.sh','--dnd'),
    'power':('powerprofile.sh','--cycle'),
    'caffeine':('caffeine.sh','--toggle'),
    'microphone':('volume.sh','--mic-toggle'),
    'mute':('volume.sh','--toggle'),
}
MENUS={'vpn':('vpn.sh','--menu'),'proxy':('proxy.sh','--menu'),
       'theme':('theme.sh','--menu'),'profile':('profile.sh','--menu'),
       'screenshot':('screenshot.sh','--area'),'mixer':('pavucontrol',),
       'bluetooth':('desktop_ui.py','bluetooth'),'binds':('desktop_ui.py','binds'),
       'events':('desktop_ui.py','events'),
       'lock':('lock.sh',),'session':('powermenu.sh',),
       'security':('rice-menu.sh',),'engagement':('engagement.sh','--menu'),
       'target':('target.sh','--menu')}


def update(**values):
    args=['eww','-c',str(Path.home()/'.config/eww'),'update']
    args += [key+'='+('true' if value is True else 'false' if value is False else str(value)) for key,value in values.items()]
    try:subprocess.run(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=2)
    except (OSError,subprocess.SubprocessError):pass


def executable(name):
    return str(HERE/name) if (HERE/name).is_file() else name


def perform(action, date=None):
    if date is not None:
        if action != "events": raise ValueError("A date is only valid for events")
        date = datetime.date.fromisoformat(date).isoformat()
    if action in MENUS:
        subprocess.run([str(HERE/'control.sh'),'--close'],timeout=4,check=True,
                       stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        command=MENUS[action]
        if date is not None: command=(*command,"--date",date)
        state=Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))/'rice'
        state.mkdir(parents=True,exist_ok=True)
        with (state/'desktop-actions.log').open('a') as log:
            subprocess.Popen([executable(command[0]),*command[1:]],stdin=subprocess.DEVNULL,
                             stdout=log,stderr=log,start_new_session=True)
        return 0
    if action not in TOGGLES:raise ValueError('Unknown control action')
    runtime=Path(os.environ.get('XDG_RUNTIME_DIR',str(Path.home()/'.cache/rice')))
    runtime.mkdir(parents=True,exist_ok=True)
    with (runtime/'rice-control-action.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        update(cc_busy=True,cc_error='',cc_active_action=action)
        try:
            script,*args=TOGGLES[action]
            result=subprocess.run([str(HERE/script),*args],capture_output=True,text=True,timeout=6)
            if result.returncode:
                message=(result.stderr.strip() or 'The service refused this action').splitlines()[0]
                raise RuntimeError(message[:240])
            return 0
        except (OSError,RuntimeError,subprocess.SubprocessError) as error:
            update(cc_error=f'{action.title()}: {error}')
            print(error,file=sys.stderr)
            return 1
        finally:update(cc_busy=False,cc_active_action="")


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=sorted([*TOGGLES,*MENUS]))
    parser.add_argument("--date")
    args=parser.parse_args()
    raise SystemExit(perform(args.action,args.date))
