#!/usr/bin/env python3
"""Start/reload the main sxhkd with private custom shortcuts; leave popup grabs alone."""
import argparse
import fcntl
import os
from pathlib import Path
import signal
import subprocess
import time


def main_processes():
    found=[]
    for p in Path('/proc').glob('[0-9]*'):
        try:
            if p.stat().st_uid != os.getuid():continue
            args=(p/'cmdline').read_bytes().rstrip(b'\0').split(b'\0')
            if args and Path(os.fsdecode(args[0])).name=='sxhkd' and not any(b'popup-keys.sxhkd' in a for a in args):
                found.append((int(p.name),args))
        except (OSError,ProcessLookupError):pass
    return found


def reload_bindings():
    runtime=runtime_directory();runtime.mkdir(parents=True,exist_ok=True)
    # sxhkd re-arms SIGUSR1 in its event loop. Two immediate reload requests
    # can hit its temporary default disposition and terminate the daemon.
    with (runtime/'rice-hotkeys-reload.lock').open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        lock.seek(0)
        try:last=float(lock.read() or '0')
        except ValueError:last=0
        delay=min(.15,max(0.,.15-(time.monotonic()-last)))
        if delay:time.sleep(delay)
        processes=main_processes()
        if not processes:
            start()
        else:
            for pid,_ in processes:
                deadline=time.monotonic()+1
                while time.monotonic()<deadline:
                    try:
                        status=(Path('/proc')/str(pid)/'status').read_text()
                        caught=next(line.split()[1] for line in status.splitlines() if line.startswith('SigCgt:'))
                        if int(caught,16)&(1<<(signal.SIGUSR1-1)):break
                    except (OSError,StopIteration):break
                    time.sleep(.005)
                else:raise OSError('Shortcut daemon is not ready to reload')
                try:os.kill(pid,signal.SIGUSR1)
                except ProcessLookupError:pass
            time.sleep(.02)
            if not main_processes():start()
        lock.seek(0);lock.truncate();lock.write(str(time.monotonic()));lock.flush()
        if not main_processes():raise OSError('Shortcut daemon could not start; check rice-hotkeys.log')


def runtime_directory():
    return Path(os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}')


def start(restart=False):
    runtime=runtime_directory();runtime.mkdir(parents=True,exist_ok=True)
    with (runtime/'rice-hotkeys-start.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        _start_locked(restart)


def _start_locked(restart=False):
    custom=Path.home()/'.config/sxhkd/custom.sxhkdrc'
    custom.parent.mkdir(parents=True,exist_ok=True)
    if not custom.exists():custom.touch(mode=0o600)
    processes=main_processes()
    if processes and not restart:return
    for pid,_ in processes:
        try:os.kill(pid,signal.SIGTERM)
        except ProcessLookupError:pass
    deadline=time.monotonic()+2
    while main_processes() and time.monotonic()<deadline:time.sleep(.02)
    runtime=runtime_directory()
    runtime.mkdir(parents=True,exist_ok=True)
    with (runtime/'rice-hotkeys.log').open('a') as log:
        process=subprocess.Popen(['sxhkd','-c',str(Path.home()/'.config/sxhkd/sxhkdrc'),str(custom)],
                         stdin=subprocess.DEVNULL,stdout=log,stderr=log,start_new_session=True)
    time.sleep(.12)
    if process.poll() is not None:raise OSError('Shortcut daemon exited; check rice-hotkeys.log')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    group=p.add_mutually_exclusive_group();group.add_argument('--restart',action='store_true');group.add_argument('--reload',action='store_true')
    args=p.parse_args()
    if args.reload:reload_bindings()
    else:start(args.restart)
