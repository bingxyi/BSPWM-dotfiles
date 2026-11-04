#!/usr/bin/env python3
"""Apply a verified power profile in one D-Bus client instead of several CLIs."""
import argparse
import sys

PROFILES=('balanced','performance','power-saver')


def next_profile(current,available):
    profiles=[p for p in PROFILES if p in available]
    if not profiles:raise ValueError('No supported power profiles')
    return profiles[(profiles.index(current)+1)%len(profiles)] if current in profiles else profiles[0]


def apply(action,value=None):
    try:
        import gi
        from gi.repository import Gio,GLib
    except ImportError:return 2
    bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
    proxy=None
    for name,path in [('org.freedesktop.UPower.PowerProfiles','/org/freedesktop/UPower/PowerProfiles'),('net.hadess.PowerProfiles','/net/hadess/PowerProfiles')]:
        try:
            properties=bus.call_sync(name,path,'org.freedesktop.DBus.Properties','GetAll',GLib.Variant('(s)',(name,)),None,Gio.DBusCallFlags.NONE,1500,None).unpack()[0]
            if 'ActiveProfile' in properties:proxy=(name,path);break
        except GLib.Error:continue
    if proxy is None:return 2
    name,path=proxy;current=properties['ActiveProfile']
    if action=='get':print('power' if current=='power-saver' else current);return 0
    if action=='cycle':value=next_profile(current,[p['Profile'] for p in properties['Profiles']])
    elif value=='power':value='power-saver'
    if value not in PROFILES:raise ValueError('Unsupported power profile')
    bus.call_sync(name,path,'org.freedesktop.DBus.Properties','Set',GLib.Variant('(ssv)',(name,'ActiveProfile',GLib.Variant('s',value))),None,Gio.DBusCallFlags.NONE,2500,None)
    actual=bus.call_sync(name,path,'org.freedesktop.DBus.Properties','Get',GLib.Variant('(ss)',(name,'ActiveProfile')),None,Gio.DBusCallFlags.NONE,1500,None).unpack()[0]
    if actual!=value:raise RuntimeError('Power service did not apply the selected profile')
    print('power' if actual=='power-saver' else actual);return 0


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['get','cycle','set']);p.add_argument('value',nargs='?');args=p.parse_args()
    try:return apply(args.action,args.value)
    except Exception as error:print(str(error),file=sys.stderr);return 1

if __name__=='__main__':raise SystemExit(main())
