#!/usr/bin/env python3
"""Calendar feed for Eww; change-driven updates, private local event storage."""
import argparse
from datetime import date
import ctypes
import json
import os
from pathlib import Path
import select
import sys
from desktop_state import EventStore, atomic_json, data_dir, locked, read_json


def payload(store=None, view=None):
    store = store or EventStore()
    view = view or store.path.parent/'view.json'
    today = date.today()
    selection = read_json(view, {'year':today.year,'month':today.month})
    return store.month(int(selection['year']),int(selection['month']),today)


def change_month(delta=None, today=False):
    path=data_dir()/'calendar/view.json'
    with locked(path):
        now=date.today();value=read_json(path,{'year':now.year,'month':now.month})
        if today:value={'year':now.year,'month':now.month}
        else:
            index=int(value['year'])*12+int(value['month'])-1+int(delta)
            year,month=divmod(index,12)
            if not 1 <= year <= 9999:raise ValueError('Month out of range')
            value={'year':year,'month':month+1}
        atomic_json(path,value)


def watch():
    store=EventStore();store.path.parent.mkdir(parents=True,exist_ok=True)
    libc=ctypes.CDLL(None,use_errno=True)
    libc.inotify_init1.argtypes=[ctypes.c_int];libc.inotify_init1.restype=ctypes.c_int
    libc.inotify_add_watch.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_uint32]
    fd=libc.inotify_init1(os.O_NONBLOCK|os.O_CLOEXEC)
    if fd < 0:raise OSError(ctypes.get_errno(),'Cannot watch calendar directory')
    libc.inotify_add_watch(fd,os.fsencode(store.path.parent),0x8|0x80|0x100|0x200)
    previous=None
    try:
        while True:
            try:current=json.dumps(payload(store),ensure_ascii=False,separators=(',',':'))
            except (ValueError,KeyError,TypeError) as error:
                print('calendar: '+str(error),file=sys.stderr)
                current=json.dumps({'title':'Calendar unavailable','today_label':'Check event data','weeks':[], 'weekdays':[], 'agenda':[], 'today':date.today().isoformat()})
            if current != previous:
                print(current,flush=True);previous=current
            select.select([fd],[],[],60)  # Also updates Today after midnight.
            try:os.read(fd,65536)
            except BlockingIOError:pass
    finally:os.close(fd)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--watch',action='store_true');p.add_argument('--month',type=int)
    p.add_argument('--today',action='store_true');args=p.parse_args()
    if args.month is not None:change_month(args.month)
    elif args.today:change_month(today=True)
    elif args.watch:watch()
    else:print(json.dumps(payload(),ensure_ascii=False))


if __name__=='__main__':main()
