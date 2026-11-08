"""Persistent desktop data and validated bindings; no GTK or session side effects."""
import calendar
from contextlib import contextmanager
from datetime import date, datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import uuid


def data_dir():
    return Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share'))) / 'rice'


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.rice-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False, indent=2)
            stream.write('\n')
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


@contextmanager
def locked(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix(path.suffix+'.lock').open('a') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def read_json(path, default):
    if not path.exists():
        return default
    # Corrupt data is an error, never an excuse to replace personal events/binds.
    return json.loads(path.read_text())


class EventStore:
    def __init__(self, path=None):
        self.path = Path(path) if path else data_dir()/'calendar/events.json'

    def all(self):
        data = read_json(self.path, {'schema': 1, 'events': []})
        if not isinstance(data, dict) or not isinstance(data.get('events'), list):
            raise ValueError('Invalid calendar data; existing file retained')
        return sorted(data['events'], key=lambda e: (e['date'], e.get('time',''), e['title']))

    def save(self, title, day, start='', notes='', event_id=None, color='#e0505a'):
        day = date.fromisoformat(day).isoformat()
        if not title.strip() or len(title.strip()) > 160:
            raise ValueError('Enter an event title (up to 160 characters)')
        if start and not re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d', start):
            raise ValueError('Use a valid time in HH:MM format, or leave it empty')
        if not re.fullmatch(r'#[0-9a-fA-F]{6}', color):
            raise ValueError('Invalid event color')
        if len(notes) > 5000:
            raise ValueError('Notes are too long')
        with locked(self.path):
            events = self.all()
            if event_id and not any(e['id']==event_id for e in events):
                raise ValueError('This event was removed in another window; reload it')
            event = {'id': event_id or str(uuid.uuid4()), 'title': title.strip(),
                     'date': day, 'time': start, 'notes': notes, 'color': color}
            events = [e for e in events if e['id'] != event['id']] + [event]
            atomic_json(self.path, {'schema': 1, 'events': events})
            return event

    def delete(self, event_id):
        with locked(self.path):
            events = self.all()
            atomic_json(self.path, {'schema': 1, 'events': [e for e in events if e['id'] != event_id]})

    def month(self, year, month, today=None):
        today = today or date.today()
        events = self.all()
        marked = {e['date'] for e in events}
        weeks = []
        for week in calendar.Calendar(firstweekday=0).monthdayscalendar(year, month):
            days = []
            for day in week:
                value = date(year,month,day).isoformat() if day else ''
                days.append({'label':str(day) if day else '', 'date':value,
                             'today':value == today.isoformat(), 'marked':value in marked,
                             'count':sum(e['date']==value for e in events) if day else 0})
            weeks.append({'days':days})
        return {'title':date(year,month,1).strftime('%B %Y'), 'today':today.isoformat(),
                'today_label':today.strftime('%a, %d %b'), 'weeks':weeks,
                'weekdays':['M','T','W','T','F','S','S'],
                'agenda':[e for e in events if e['date']==today.isoformat()]}


def expand(text):
    match = re.search(r'\{([^{}]*)\}', text)
    if not match:
        return [text]
    return [entry for value in match[1].split(',') for entry in
            expand(text[:match.start()]+value+text[match.end():])]


MODIFIERS = ('super','ctrl','alt','shift')
ALIASES = {'control':'ctrl','mod4':'super','win':'super'}

def canonical_chord(chord):
    parts = [ALIASES.get(p.strip().lower(),p.strip()) for p in chord.split('+')]
    modifiers = {p.lower() for p in parts if p.lower() in MODIFIERS}
    keys = [p for p in parts if p.lower() not in MODIFIERS]
    if 'super' not in modifiers:
        raise ValueError('Every shortcut must include SUPER')
    if len(keys) != 1 or not re.fullmatch(r'[A-Za-z0-9_]+',keys[0]):
        raise ValueError('Press SUPER with a regular key; modifiers alone are not a shortcut')
    key = keys[0].lower() if len(keys[0]) == 1 else keys[0]
    if key.lower() in ('super_l','super_r','control_l','control_r','shift_l','shift_r','alt_l','alt_r'):
        raise ValueError('Add a regular key to the modifiers')
    return ' + '.join([m for m in MODIFIERS if m in modifiers]+[key])


def reserved_chords(path):
    result = set()
    if path.is_file():
        for line in path.read_text().splitlines():
            if not line or line[0].isspace() or line.startswith('#'):
                continue
            for entry in expand(line):
                try:result.add(canonical_chord(entry))
                except ValueError:pass  # Non-Super hardware binds are reserved separately.
    return result


def action_catalog():
    base = '~/.config/rice/bin/'
    choices = [
        ('terminal','Open terminal','kitty'),
        ('floating-terminal','Floating terminal','kitty --class scratchpad'),
        ('browser','Browser','firefox'),('files','File manager','thunar'),
        ('editor','Neovim','kitty -e nvim'),('launcher','Application launcher',base+'launcher.sh'),
        ('control','Control center',base+'control.sh --toggle'),
        ('bluetooth','Bluetooth',base+'desktop_ui.py bluetooth'),
        ('calendar','Calendar / events',base+'desktop_ui.py events'),
        ('animation-settings','animation settings',base+'desktop_ui.py animations'),
        ('media','Media center',base+'media.sh --toggle'),
        ('notifications','Notifications',base+'notifications.sh --toggle'),
        ('theme','Theme selector',base+'theme.sh --menu'),
        ('wallpaper','Wallpaper selector',base+'wallpaper.sh --menu'),
        ('screenshot','Area screenshot',base+'screenshot.sh --area'),
        ('full-screenshot','Full screenshot',base+'screenshot.sh --full'),
        ('keep-awake','Toggle keep awake',base+'caffeine.sh --toggle'),
        ('power','Power profile',base+'powerprofile.sh --cycle'),
        ('lock','Lock screen',base+'lock.sh'),('session','Session menu',base+'powermenu.sh'),
        ('volume-up','Volume up',base+'volume.sh --up'),('volume-down','Volume down',base+'volume.sh --down'),
        ('mute','Toggle mute',base+'volume.sh --toggle'),
        ('close','Close focused window','bspc node -c'),
        ('fullscreen','Toggle fullscreen','bspc node -t "~"fullscreen'),
        ('float','Toggle floating','bspc node -t "~"floating'),
        ('tools','Security tools',base+'rice-menu.sh'),('engagement','Engagement terminal',base+'engagement.sh --terminal')]
    choices += [('workspace-'+str(n),'Workspace '+str(n),base+'workspace.sh --focus '+str(n)) for n in range(1,11)]
    return choices


class BindStore:
    def __init__(self, config=None):
        self.config = Path(config) if config else Path.home()/'.config'
        self.path = self.config/'rice/custom-binds.json'
        self.rendered = self.config/'sxhkd/custom.sxhkdrc'
        self.base = self.config/'sxhkd/sxhkdrc'

    def all(self):
        data = read_json(self.path, {'schema':1,'bindings':[]})
        if not isinstance(data,dict) or not isinstance(data.get('bindings'),list):
            raise ValueError('Invalid shortcut data; existing files retained')
        return data['bindings']

    def save(self, chord, action, binding_id=None):
        chord = canonical_chord(chord)
        catalog = {key:(label,command) for key,label,command in action_catalog()}
        if action not in catalog:
            raise ValueError('Choose a supported action')
        if chord in reserved_chords(self.base):
            raise ValueError('This combination is already used by a built-in shortcut')
        with locked(self.path):
            entries = self.all()
            if any(b['chord']==chord and b['id']!=binding_id for b in entries):
                raise ValueError('This combination is already saved')
            item = {'id':binding_id or str(uuid.uuid4()),'chord':chord,'action':action}
            entries = [b for b in entries if b['id'] != item['id']]+[item]
            self._write(entries,catalog)
            return item

    def delete(self, binding_id):
        with locked(self.path):
            self._write([b for b in self.all() if b['id']!=binding_id],
                        {key:(label,command) for key,label,command in action_catalog()})

    def _write(self, entries, catalog):
        text = '# Personal shortcuts — managed by Bind Saver; all combinations require SUPER.\n'
        for item in entries:
            chord = canonical_chord(item['chord'])
            if item['action'] not in catalog:raise ValueError('Unsupported saved action')
            label,command = catalog[item['action']]
            text += '\n# '+label+'\n'+chord+'\n\t'+command+'\n'
        # Keep history for recovery; avoid touching the upstream sxhkd file.
        if self.path.exists():
            history = self.path.parent/'bind-history'
            history.mkdir(exist_ok=True)
            shutil.copy2(self.path, history/(datetime.now().strftime('%Y%m%d-%H%M%S-%f')+'.json'))
        self.rendered.parent.mkdir(parents=True,exist_ok=True)
        fd,name = tempfile.mkstemp(prefix='.custom-',dir=self.rendered.parent)
        try:
            with os.fdopen(fd,'w') as stream:stream.write(text)
            os.replace(name,self.rendered)
        finally:Path(name).unlink(missing_ok=True)
        atomic_json(self.path,{'schema':1,'bindings':entries})
