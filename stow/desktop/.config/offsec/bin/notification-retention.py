#!/usr/bin/env python3
"""Local DND receipt clock and history writer. Never forwards notification data."""
import argparse
from contextlib import contextmanager
from datetime import datetime
import fcntl
import json
import math
import os
from pathlib import Path
import tempfile
import time

STATE = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'offsec'
TTL = 7200


@contextmanager
def locked():
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / 'notifications.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def read(name, default):
    try:
        return json.loads((STATE / name).read_text())
    except FileNotFoundError:
        return default


def rows():
    try:
        return [json.loads(line) for line in (STATE / 'notifications.json').read_text().splitlines() if line]
    except FileNotFoundError:
        return []


def write(name, value, lines=False):
    fd, tmp = tempfile.mkstemp(prefix='.notifications-', dir=STATE)
    try:
        with os.fdopen(fd, 'w') as out:
            if lines:
                out.writelines(json.dumps(row, ensure_ascii=False) + '\n' for row in value)
            else:
                json.dump(value, out)
        os.replace(tmp, STATE / name)
    finally:
        Path(tmp).unlink(missing_ok=True)


def keep(row):
    if row['urgency'] == 'critical':
        return True
    return not (row['app'] in ('offsec-osd', 'archlinux-osd') or
                (row['app'] in ('offsec', 'archlinux') and row['urgency'] == 'low') or
                (row['app'] == 'kitty' and row['summary'] == 'kitty'))


def append(row):
    if not keep(row) or row.get('expires_at', math.inf) <= time.time():
        return
    previous = rows()
    key = ('app', 'summary', 'body', 'urgency')
    previous = [old for old in previous if any(old.get(k) != row.get(k) for k in key)]
    write('notifications.json', (previous + [row])[-20:], lines=True)


def log_environment():
    env = os.environ
    row = dict(app=env.get('DUNST_APP_NAME', 'unknown'), summary=env.get('DUNST_SUMMARY', ''),
               body=env.get('DUNST_BODY', ''), icon=env.get('DUNST_ICON_PATH', ''),
               urgency=env.get('DUNST_URGENCY', 'normal').lower(), time=datetime.now().strftime('%H:%M'))
    row['notification_id'] = env.get('DUNST_ID', '')
    with locked():
        receipt = read('dnd-receipts.json', {}).get(env.get('DUNST_ID', ''))
        if receipt:
            row.update(received_at=receipt['received_at'], expires_at=receipt['expires_at'],
                       daemon_owner=receipt['owner'])
        append(row)


class Watcher:
    def __init__(self, ttl=TTL):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib, self.ttl = Gio, GLib, ttl
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.pending = {}
        self.owner = self.call('org.freedesktop.DBus', '/org/freedesktop/DBus',
                               'org.freedesktop.DBus', 'GetNameOwner',
                               GLib.Variant('(s)', ('org.freedesktop.Notifications',)))[0]
        self.paused = self.call('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                                'org.freedesktop.DBus.Properties', 'Get',
                                GLib.Variant('(ss)', ('org.dunstproject.cmd0', 'paused')))[0]
        self.bus.signal_subscribe('org.freedesktop.DBus', 'org.freedesktop.DBus', 'NameOwnerChanged',
                                  '/org/freedesktop/DBus', 'org.freedesktop.Notifications', 0, self.owner_changed)
        flags = Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION
        self.monitor = Gio.DBusConnection.new_for_address_sync(
            os.environ['DBUS_SESSION_BUS_ADDRESS'], flags, None, None)
        self.monitoring = False
        self.monitor.add_filter(self.filter_message)
        matches = ["type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
                   "type='method_return',sender='org.freedesktop.Notifications'",
                   "type='signal',sender='org.freedesktop.Notifications',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"]
        self.monitor.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus',
                               'org.freedesktop.DBus.Monitoring', 'BecomeMonitor',
                               GLib.Variant('(asu)', (matches, 0)), None, 0, 3000, None)
        self.monitoring = True
        self.monitor.connect('closed', self.monitor_closed)
        self.timer = None
        self.expire()
        print('DND retention ready: local notification monitor, TTL=7200s' if ttl == TTL
              else f'DND retention test ready: TTL={ttl}s', flush=True)

    def call(self, dest, path, interface, method, parameters=None):
        return self.bus.call_sync(dest, path, interface, method, parameters,
                                  None, 0, 3000, None).unpack()

    def owner_changed(self, connection, sender, path, interface, signal, params):
        _, old, new = params.unpack()
        # Let systemd reconnect instead of trusting IDs reused by a new daemon.
        if old == self.owner:
            raise SystemExit('Dunst owner changed; reconnecting')

    def monitor_closed(self, *args):
        raise SystemExit('Notification monitor disconnected; reconnecting')

    def filter_message(self, connection, message, incoming, *unused):
        if incoming and self.monitoring:
            self.GLib.idle_add(self.receive, message.copy())
            # Consume observed calls: GDBus must never answer on a monitor connection.
            return None
        return message

    def receive(self, message):
        typ = message.get_message_type()
        if typ == self.Gio.DBusMessageType.SIGNAL and message.get_member() == 'PropertiesChanged':
            name, changed, invalidated = message.get_body().unpack()
            if message.get_sender() == self.owner and name == 'org.dunstproject.cmd0' and 'paused' in changed:
                self.paused = changed['paused']
        elif typ == self.Gio.DBusMessageType.METHOD_CALL and message.get_member() == 'Notify':
            self.pending[(message.get_sender(), message.get_serial())] = (
                message.get_body().unpack(), self.paused, time.time())
        elif typ == self.Gio.DBusMessageType.METHOD_RETURN and message.get_sender() == self.owner:
            request = self.pending.pop((message.get_destination(), message.get_reply_serial()), None)
            if request:
                params, paused, received = request
                self.record(message.get_body().unpack()[0], params, paused, received)
        # Discard requests without replies; store no unbounded notification payloads.
        now = time.time()
        self.pending = {key: value for key, value in self.pending.items() if now - value[2] < 15}
        return False

    def record(self, ident, params, paused, received):
        app, replaces, icon, summary, body, actions, hints, timeout = params
        with locked():
            ledger = read('dnd-receipts.json', {})
            if paused:
                receipt = dict(owner=self.owner, received_at=received, expires_at=received + self.ttl)
                ledger[str(ident)] = receipt
                urgency = ('low', 'normal', 'critical')[min(int(hints.get('urgency', 1)), 2)]
                append(dict(app=app, summary=summary, body=body, icon=icon, urgency=urgency,
                            notification_id=str(ident), daemon_owner=self.owner,
                            time=datetime.fromtimestamp(received).strftime('%H:%M'),
                            received_at=received, expires_at=receipt['expires_at']))
            else:
                ledger.pop(str(ident), None)
                history = rows()
                for row in history:
                    if row.get('notification_id') == str(ident) and row.get('daemon_owner') == self.owner:
                        row.pop('received_at', None)
                        row.pop('expires_at', None)
                write('notifications.json', history, lines=True)
            write('dnd-receipts.json', ledger)
        self.schedule()

    def schedule(self):
        if self.timer is not None:
            self.GLib.source_remove(self.timer)
        with locked():
            deadlines = [entry['expires_at'] for entry in read('dnd-receipts.json', {}).values()]
            deadlines += [row['expires_at'] for row in rows() if 'expires_at' in row]
        delay = max(1, int((min(deadlines) - time.time()) * 1000)) if deadlines else 60000
        self.timer = self.GLib.timeout_add(min(delay, 60000), self.expire)

    def expire(self):
        self.timer = None
        with locked():
            now = time.time()
            ledger = read('dnd-receipts.json', {})
            retained = {}
            for ident, receipt in ledger.items():
                if receipt['owner'] != self.owner:
                    continue
                if receipt['expires_at'] > now:
                    retained[ident] = receipt
                    continue
                try:
                    self.call('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                              'org.freedesktop.Notifications', 'CloseNotification',
                              self.GLib.Variant('(u)', (int(ident),)))
                    self.call('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                              'org.dunstproject.cmd0', 'NotificationRemoveFromHistory',
                              self.GLib.Variant('(u)', (int(ident),)))
                    # Replaced notifications may have several history rows with one ID.
                    history = self.call('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                                        'org.dunstproject.cmd0', 'NotificationListHistory')[0]
                    for row in history:
                        if row.get('id') == int(ident):
                            self.call('org.freedesktop.Notifications', '/org/freedesktop/Notifications',
                                      'org.dunstproject.cmd0', 'NotificationRemoveFromHistory',
                                      self.GLib.Variant('(u)', (int(ident),)))
                except self.GLib.Error:
                    # Retry failed deletion; never silently forget a queued ID.
                    retained[ident] = receipt
            write('dnd-receipts.json', retained)
            write('notifications.json', [row for row in rows() if row.get('expires_at', math.inf) > now], lines=True)
        self.schedule()
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--watch', action='store_true')
    args = parser.parse_args()
    if args.watch:
        from gi.repository import GLib
        Watcher()
        GLib.MainLoop().run()
    else:
        log_environment()


if __name__ == '__main__':
    main()
