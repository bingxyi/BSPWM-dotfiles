#!/usr/bin/python
"""MPRIS stream for Eww; runs only while the media window uses it."""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request

import gi
gi.require_version('Playerctl', '2.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import GLib, GdkPixbuf, Playerctl

CACHE = Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'rice/media'
STATE = Path(os.environ.get('XDG_RUNTIME_DIR', str(CACHE))) / 'rice-media.json'
PREFERENCE = STATE.with_name('rice-media-preferred')
EMPTY = dict(available=False, title='Nothing playing', artist='Play a song or video',
             album='', player='', playing=False, art=str(Path.home() / '.config/rice/media-placeholder.svg'), has_art=False, progress=0,
             elapsed='0:00', duration='0:00', can_seek=False, can_play=False,
             can_previous=False, can_next=False, volume=0, muted=False)


def atomic_write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(value)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def players():
    result = []
    for name in Playerctl.list_players():
        try:
            result.append(Playerctl.Player.new_from_name(name))
        except GLib.Error:
            pass
    return result


def choose(available):
    try:
        preferred = PREFERENCE.read_text()
    except OSError:
        preferred = ''
    return next((p for p in available if p.props.player_instance == preferred), None) or next(
        (p for p in available if p.props.playback_status == Playerctl.PlaybackStatus.PLAYING),
        next((p for p in available if p.props.player_name == 'spotify'), available[0] if available else None))


def timestamp(us):
    seconds = max(0, int(us) // 1_000_000)
    return f'{seconds // 60}:{seconds % 60:02d}'


def validate_url(url):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ('http', 'https') or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError('unsupported artwork URL')
    for addr in socket.getaddrinfo(parsed.hostname, parsed.port or (443 if parsed.scheme == 'https' else 80)):
        if not ipaddress.ip_address(addr[4][0]).is_global:
            raise ValueError('non-public artwork host')
    return url


class ArtRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return super().redirect_request(req, fp, code, msg, headers, validate_url(newurl))


class Stream:
    def __init__(self):
        CACHE.mkdir(parents=True, exist_ok=True)
        self.manager = Playerctl.PlayerManager()
        self.manager.connect('name-appeared', self.appeared)
        self.manager.connect('player-vanished', lambda *_: self.emit())
        self.last = None
        self.instance = None
        self.art_url = ''
        self.art_path = ''
        self.art_generation = 0
        self.art_retry_after = 0
        self.ticks = 0
        self.volume = 0
        self.muted = False
        for name in self.manager.props.player_names:
            self.appeared(self.manager, name)
        self.tick()
        GLib.timeout_add_seconds(1, self.tick)

    def appeared(self, manager, name):
        try:
            player = Playerctl.Player.new_from_name(name)
            for signal in ('metadata', 'playback-status', 'seeked'):
                player.connect(signal, lambda *_: self.emit())
            manager.manage_player(player)
        except GLib.Error:
            pass

    def tick(self):
        if self.ticks % 2 == 0:
            try:
                raw = subprocess.run(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'],
                                     capture_output=True, text=True, timeout=1).stdout
                self.volume = min(100, max(0, round(float(raw.split()[1]) * 100)))
                self.muted = 'MUTED' in raw
            except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
                pass
        self.ticks += 1
        self.emit()
        return True

    def artwork(self, url):
        if url == self.art_url and (self.art_path or time.monotonic() < self.art_retry_after):
            return
        self.art_url, self.art_path = url, ''
        self.art_generation += 1
        generation = self.art_generation
        if not url:
            return
        self.art_retry_after = time.monotonic() + 30
        path = CACHE / (hashlib.sha256(url.encode()).hexdigest() + '.png')
        if path.is_file():
            try:
                GdkPixbuf.Pixbuf.new_from_file(str(path))
                self.art_path = str(path)
                return
            except GLib.Error:
                path.unlink(missing_ok=True)
        def fetch():
            temporary = None
            try:
                parsed = urllib.parse.urlsplit(url)
                if parsed.scheme == 'file' and parsed.netloc in ('', 'localhost'):
                    with open(urllib.request.url2pathname(parsed.path), 'rb') as stream:
                        data = stream.read(5_000_001)
                else:
                    request = urllib.request.Request(validate_url(url), headers={'User-Agent': 'RiceMedia/1.0'})
                    with urllib.request.build_opener(ArtRedirect()).open(request, timeout=5) as response:
                        data = response.read(5_000_001)
                if len(data) > 5_000_000:
                    return
                loader = GdkPixbuf.PixbufLoader()
                loader.connect('size-prepared', lambda obj, w, h: obj.set_size(240, 240))
                loader.write(data)
                loader.close()
                pixbuf = loader.get_pixbuf()
                if pixbuf:
                    fd, temporary = tempfile.mkstemp(prefix='.cover-', suffix='.png', dir=CACHE)
                    os.close(fd)
                    pixbuf.savev(temporary, 'png', [], [])
                    os.replace(temporary, path)
                    temporary = None
                    GLib.idle_add(self.art_ready, generation, str(path))
            except (OSError, ValueError, GLib.Error):
                pass
            finally:
                if temporary:
                    Path(temporary).unlink(missing_ok=True)
        threading.Thread(target=fetch, daemon=True).start()

    def art_ready(self, generation, path):
        if generation == self.art_generation:
            self.art_path = path
            self.emit()
        return False

    def emit(self):
        value = dict(EMPTY, volume=self.volume, muted=self.muted)
        player = choose(self.manager.props.players)
        try:
            if player:
                metadata = player.props.metadata.unpack()
                length = max(0, int(metadata.get('mpris:length', 0)))
                position = max(0, player.get_position())
                self.artwork(str(metadata.get('mpris:artUrl', '')))
                value.update(available=True, title=str(metadata.get('xesam:title') or 'Untitled media'),
                             artist=' · '.join(metadata.get('xesam:artist', [])) or player.props.player_name,
                             album=str(metadata.get('xesam:album', '')), player=player.props.player_name,
                             playing=player.props.playback_status == Playerctl.PlaybackStatus.PLAYING,
                             art=self.art_path or EMPTY['art'], has_art=bool(self.art_path),
                             progress=min(100, 100 * position / length) if length else 0,
                             elapsed=timestamp(position), duration=timestamp(length),
                             can_seek=player.props.can_seek and length > 0,
                             can_play=player.props.can_play or player.props.can_pause,
                             can_previous=player.props.can_go_previous, can_next=player.props.can_go_next)
                instance = player.props.player_instance
            else:
                self.artwork('')
                instance = ''
            if instance != self.instance:
                atomic_write(STATE, json.dumps({'instance': instance}))
                self.instance = instance
        except GLib.Error:
            return
        line = json.dumps(value, ensure_ascii=False)
        if line != self.last:
            self.last = line
            try:
                print(line, flush=True)
            except BrokenPipeError:
                os._exit(0)


def cycle_player():
    available = players()
    current = choose(available)
    if current and available:
        selected = available[(available.index(current) + 1) % len(available)]
        atomic_write(PREFERENCE, selected.props.player_instance)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['watch', 'cycle'], default='watch', nargs='?')
    args = parser.parse_args()
    try:
        if args.command == 'watch':
            Stream()
            GLib.MainLoop().run()
        else:
            cycle_player()
    except (GLib.Error, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
