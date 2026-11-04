#!/usr/bin/env python3
"""One BSPWM snapshot per workspace redraw, shared by tint2 and Eww."""
import argparse
import html
import json
from pathlib import Path
import subprocess

ICONS=['󰞷','󰈹','󰯄','󰅴','󰉋','󰅩','󰠮','󰝚','󰢹','󰀻']
ROLES=['terminal','web','proxy/burp','code','files','network','notes','media','vm/remote','miscellaneous']


def flags(node):
    if not node:return False,False
    client=node.get('client') or {}
    occupied=bool(client);urgent=bool(client.get('urgent'))
    for key in ('firstChild','secondChild'):
        child_occupied,child_urgent=flags(node.get(key))
        occupied|=child_occupied;urgent|=child_urgent
    return occupied,urgent


def workspaces(tree):
    values=[]
    for monitor in tree['monitors']:
        for desktop in monitor['desktops']:
            index=len(values);occupied,urgent=flags(desktop.get('root'))
            focused=monitor['id']==tree['focusedMonitorId'] and desktop['id']==monitor['focusedDesktopId']
            state='focused' if focused else 'urgent' if urgent else 'occupied' if occupied else 'free'
            values.append(dict(name=desktop['name'],icon=ICONS[index%10],role=ROLES[index%10],state=state))
    return values


def tint2(values,palette):
    lines=[]
    for index in range(10):
        if index>=len(values):lines.append('');continue
        value=values[index];state=value['state']
        color=palette.get({'focused':'accent','urgent':'urgent','occupied':'fg','free':'muted'}[state],'#9c93b0')
        size={'focused':'x-large','occupied':'medium','urgent':'medium','free':'small'}[state]
        weight='bold' if state=='focused' else 'normal'
        lines.append(f'<span foreground="{html.escape(color,quote=True)}" size="{size}" weight="{weight}">{value["icon"]}</span>')
    return '\n'.join(lines)


def render(as_tint2=False):
    tree=json.loads(subprocess.check_output(['bspc','wm','-d'],text=True,timeout=2))
    values=workspaces(tree)
    if not as_tint2:return json.dumps(values,ensure_ascii=False)
    palette={}
    p=Path.home()/'.config/rice/current-theme.conf'
    if p.exists():palette=dict(line.split('=',1) for line in p.read_text().splitlines() if '=' in line and not line.startswith('#'))
    return tint2(values,palette)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--tint2',action='store_true')
    parser.add_argument('--watch',action='store_true')
    args=parser.parse_args()
    if not args.watch:print(render(args.tint2),flush=True);return
    # Keep Python warm and wait on bspwm's event stream: no periodic subprocesses.
    with subprocess.Popen(['bspc','subscribe','desktop','node_add','node_remove','node_transfer','node_flag','monitor_focus'],stdout=subprocess.PIPE,text=True) as listener:
        previous=render(args.tint2);print(previous,flush=True)
        for _event in listener.stdout:
            current=render(args.tint2)
            if current!=previous:print(current,flush=True);previous=current

if __name__=='__main__':main()
