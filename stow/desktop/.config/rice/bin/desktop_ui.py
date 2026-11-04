#!/usr/bin/env python3
"""Centered desktop dialogs: Bluetooth, Super-only shortcut capture and calendar events."""
import argparse
import os
from datetime import date
from pathlib import Path
import sys
# Use the same session bus as the shell helpers even if the launching panel
# inherited an empty DBUS_SESSION_BUS_ADDRESS from an older login.
_user_bus=Path(os.environ.get('XDG_RUNTIME_DIR',f'/run/user/{os.getuid()}'))/'bus'
if not os.environ.get('DBUS_SESSION_BUS_ADDRESS') and _user_bus.is_socket():
    os.environ['DBUS_SESSION_BUS_ADDRESS']='unix:path='+str(_user_bus)
import gi

gi.require_version('Gtk','3.0')
from gi.repository import Gtk, Gdk, Gio, GLib
from desktop_state import BindStore, EventStore, action_catalog, canonical_chord, reserved_chords
from hotkeys import reload_bindings


def colors():
    result={'bg':'#1b1215','surface':'#2a1c21','overlay':'#3a272d','fg':'#f2d7d9','fg_dim':'#c9a9ae','accent':'#e0505a','red':'#ff6b6b'}
    p=Path.home()/'.config/rice/current-theme.conf'
    if p.exists():
        for line in p.read_text().splitlines():
            if '=' in line:
                k,v=line.split('=',1)
                if k in result and v.startswith('#') and len(v)==7:result[k]=v
    return result


def theme():
    c=colors()
    css='''
    window.rice-dialog {background: BG; color: FG; font-family: "Inter", "Noto Sans"; font-size: 13px;}
    .rice-dialog headerbar {background: SURFACE; color: FG; border: none; box-shadow: none;}
    .rice-dialog button {border-radius: 10px; background: SURFACE; color: FG; border: 1px solid OVERLAY; padding: 9px 13px; transition: background-color 140ms ease;}
    .rice-dialog button:hover {background: OVERLAY;}
    .rice-dialog button.suggested-action {background: ACCENT; color: #ffffff; border-color: ACCENT;}
    .rice-dialog button.danger {color: RED;}
    .rice-dialog entry, .rice-dialog textview text, .rice-dialog combobox button {background: SURFACE; color: FG; border-radius: 9px; border-color: OVERLAY; padding: 9px;}
    .rice-dialog .title {font-size: 22px; font-weight: bold;}
    .rice-dialog .muted {color: FG_DIM; font-size: 12px;}
    .rice-dialog .error {color: RED;}
    .rice-dialog .capture {font-family: "JetBrainsMono Nerd Font"; font-size: 22px; padding: 22px; border: 2px solid ACCENT;}
    .rice-dialog list, .rice-dialog row {background: transparent; color: FG;}
    .rice-dialog row {padding: 6px; border-bottom: 1px solid SURFACE;}
    .rice-dialog calendar {background: SURFACE; border-radius: 12px; padding: 10px; color: FG;}
    .rice-dialog calendar:selected {background: ACCENT; color: #fff;}
    .rice-dialog calendar.highlight {color: ACCENT;}
    '''
    for token,key in [('FG_DIM','fg_dim'),('SURFACE','surface'),('OVERLAY','overlay'),('ACCENT','accent'),('BG','bg'),('FG','fg'),('RED','red')]:css=css.replace(token,c[key])
    provider=Gtk.CssProvider();provider.load_from_data(css.encode())
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)


def label(text='',style=None):
    item=Gtk.Label(label=text,xalign=0);item.set_line_wrap(True)
    if style:item.get_style_context().add_class(style)
    return item


def button(text,callback,style=None):
    item=Gtk.Button(label=text);item.connect('clicked',callback)
    if style:item.get_style_context().add_class(style)
    return item


def clear(container):
    for child in container.get_children():container.remove(child)


def confirm(parent,title,detail):
    dialog=Gtk.MessageDialog(transient_for=parent,modal=True,message_type=Gtk.MessageType.QUESTION,
                             buttons=Gtk.ButtonsType.OK_CANCEL,text=title)
    dialog.format_secondary_text(detail)
    answer=dialog.run()==Gtk.ResponseType.OK;dialog.destroy();return answer


class Window(Gtk.ApplicationWindow):
    def __init__(self,app,title,subtitle,width=650,height=680):
        super().__init__(application=app,title=title)
        self.get_style_context().add_class('rice-dialog')
        self.set_default_size(width,height)
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_skip_taskbar_hint(True)
        self.set_resizable(True)
        self.body=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=14,margin=22)
        self.add(self.body)
        self.body.pack_start(label(title,'title'),False,False,0)
        self.body.pack_start(label(subtitle,'muted'),False,False,0)
        self.status=label('','error')
        self.connect('key-press-event',self.escape)
        self.connect('map-event',lambda *_:GLib.idle_add(self.center))

    def center(self):
        display=self.get_display();monitor=display.get_primary_monitor() or display.get_monitor(0)
        area=monitor.get_workarea();width,height=self.get_size()
        self.move(area.x+(area.width-width)//2,area.y+(area.height-height)//2)
        return False

    def escape(self,_widget,event):
        if event.keyval==Gdk.KEY_Escape:self.close();return True
        return False

    def error(self,error):self.status.set_text(str(error).split('\n')[0])

    def scroller(self,child,height=160):
        scroll=Gtk.ScrolledWindow();scroll.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(height);scroll.add(child)
        return scroll


class BindWindow(Window):
    def __init__(self,app):
        super().__init__(app,'Bind saver','Capture a shortcut, choose an action, and save it. SUPER is required.',680,690)
        self.store=BindStore();self.catalog=action_catalog();self.current_id=None;self.chord='';self.capturing=False;self.seat=None
        self.capture=button('Click to capture a shortcut',self.begin_capture,'capture')
        self.body.pack_start(self.capture,False,False,0)
        self.hint=label('Click capture, hold SUPER, then press your combination. Escape cancels capture.','muted')
        self.body.pack_start(self.hint,False,False,0)
        self.actions=Gtk.ComboBoxText()
        for action,title,_ in self.catalog:self.actions.append(action,title)
        self.actions.set_active(0)
        self.body.pack_start(label('Action'),False,False,0);self.body.pack_start(self.actions,False,False,0)
        row=Gtk.Box(spacing=8)
        row.pack_start(button('New',self.new),False,False,0)
        row.pack_end(button('Save shortcut',self.save,'suggested-action'),False,False,0)
        self.body.pack_start(row,False,False,0)
        self.body.pack_start(self.status,False,False,0)
        self.body.pack_start(label('YOUR SHORTCUTS','muted'),False,False,0)
        self.list=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=4)
        self.body.pack_start(self.scroller(self.list),True,True,0)
        self.body.pack_end(label('Built-in shortcuts are protected. Personal binds stay in ~/.config/sxhkd/custom.sxhkdrc.','muted'),False,False,0)
        # Use a keyboard grab during capture so existing global binds do not run.
        self.connect('key-press-event',self.key)
        self.connect('key-release-event',self.key_release)
        self.connect('destroy',lambda *_:self.release())
        self.refresh()

    def escape(self,_widget,event):
        if event.keyval==Gdk.KEY_Escape and not self.capturing:self.close();return True
        return False

    def begin_capture(self,_button):
        self.status.set_text('');self.chord='';self.capture.set_label('Press SUPER + …')
        self.seat=self.get_display().get_default_seat()
        result=self.seat.grab(self.get_window(),Gdk.SeatCapabilities.KEYBOARD,False,None,None,None,None)
        self.capturing=result==Gdk.GrabStatus.SUCCESS
        if not self.capturing:self.error('Keyboard is busy. Close other menus and try again.')
        else:self.hint.set_text('Listening… your pressed keys appear here without launching their actions.')

    def release(self):
        if self.seat:self.seat.ungrab()
        self.seat=None;self.capturing=False

    def key(self,_widget,event):
        if not self.capturing:return False
        if event.keyval==Gdk.KEY_Escape:
            self.release();self.capture.set_label('Click to capture a shortcut');return True
        names=[];state=event.state
        name=Gdk.keyval_name(event.keyval) or ''
        if state & (Gdk.ModifierType.SUPER_MASK|Gdk.ModifierType.MOD4_MASK) or name.startswith('Super_'):names.append('super')
        if state & Gdk.ModifierType.CONTROL_MASK or name.startswith('Control_'):names.append('ctrl')
        if state & Gdk.ModifierType.MOD1_MASK or name.startswith('Alt_'):names.append('alt')
        if state & Gdk.ModifierType.SHIFT_MASK or name.startswith('Shift_'):names.append('shift')
        modifier=name.startswith(('Super_','Shift_','Control_','Alt_','Meta_','Hyper_'))
        if not modifier:names.append(Gdk.keyval_name(Gdk.keyval_to_lower(event.keyval)) or name)
        text=' + '.join(names);self.capture.set_label(text.upper() if modifier else text)
        if not modifier:
            try:self.chord=canonical_chord(text);self.status.set_text('')
            except ValueError as error:self.chord='';self.error(error)
        return True

    def key_release(self,_widget,event):
        if not self.capturing:return False
        name=Gdk.keyval_name(event.keyval) or ''
        if not name.startswith(('Super_','Shift_','Control_','Alt_','Meta_','Hyper_')):
            self.release();self.hint.set_text('Combination captured. Choose an action and save, or click to capture again.')
        else:
            state=event.state
            groups=[('Super_',Gdk.ModifierType.SUPER_MASK|Gdk.ModifierType.MOD4_MASK,'SUPER'),
                    ('Control_',Gdk.ModifierType.CONTROL_MASK,'CTRL'),
                    ('Alt_',Gdk.ModifierType.MOD1_MASK,'ALT'),
                    ('Shift_',Gdk.ModifierType.SHIFT_MASK,'SHIFT')]
            names=[label for prefix,mask,label in groups if state & mask and not name.startswith(prefix)]
            self.capture.set_label(' + '.join(names) if names else 'Press SUPER + …')
        return True

    def new(self,_button=None):
        self.release();self.current_id=None;self.chord='';self.capture.set_label('Click to capture a shortcut');self.status.set_text('')

    def save(self,_button):
        self.release()
        try:
            item=self.store.save(self.chord,self.actions.get_active_id(),self.current_id)
            self.current_id=item['id'];reload_bindings();self.status.set_text('Shortcut saved and loaded.');self.refresh()
        except (ValueError,OSError) as error:self.error(error)

    def edit(self,item):
        self.current_id=item['id'];self.chord=item['chord'];self.capture.set_label(item['chord']);self.actions.set_active_id(item['action'])

    def delete(self,item):
        try:
            self.store.delete(item['id']);reload_bindings();self.new();self.refresh()
        except (ValueError,OSError) as error:self.error(error)

    def refresh(self):
        clear(self.list)
        try:
            entries=self.store.all();titles={a:t for a,t,_ in self.catalog}
            for item in entries:
                row=Gtk.Box(spacing=8)
                text=label(item['chord']+'\n'+titles.get(item['action'],item['action']));text.set_hexpand(True)
                row.pack_start(text,True,True,0)
                row.pack_end(button('Remove',lambda _,i=item:self.delete(i),'danger'),False,False,0)
                row.pack_end(button('Edit',lambda _,i=item:self.edit(i)),False,False,0)
                self.list.pack_start(row,False,False,6)
            if not entries:self.list.pack_start(label('No personal shortcuts yet.','muted'),False,False,0)
            self.list.show_all()
        except (ValueError,OSError) as error:self.error(error)


class EventWindow(Window):
    def __init__(self,app,selected=None):
        super().__init__(app,'Calendar & events','Local events, private to this account. Days with events are marked in the control center.',680,760)
        self.store=EventStore();self.event_id=None
        self.calendar=Gtk.Calendar();self.calendar.set_display_options(Gtk.CalendarDisplayOptions.SHOW_HEADING|Gtk.CalendarDisplayOptions.SHOW_DAY_NAMES)
        self.body.pack_start(self.calendar,False,False,0)
        todayrow=Gtk.Box(spacing=8);todayrow.pack_start(label('TODAY · '+date.today().strftime('%A, %d %B'),'muted'),True,True,0)
        todayrow.pack_end(button('Today',lambda _:self.select_date(date.today()),'suggested-action'),False,False,0)
        self.body.pack_start(todayrow,False,False,0)
        self.day_label=label('','title');self.body.pack_start(self.day_label,False,False,0)
        self.events=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=5)
        self.body.pack_start(self.scroller(self.events,90),True,True,0)
        self.title_entry=Gtk.Entry(placeholder_text='Event title');self.title_entry.set_max_length(160)
        self.time_entry=Gtk.Entry(placeholder_text='Time HH:MM (optional)');self.time_entry.set_width_chars(16)
        form=Gtk.Box(spacing=8);form.pack_start(self.title_entry,True,True,0);form.pack_start(self.time_entry,False,False,0)
        self.body.pack_start(form,False,False,0)
        self.notes=Gtk.Entry(placeholder_text='Notes (optional)');self.notes.set_max_length(5000)
        self.body.pack_start(self.notes,False,False,0)
        buttons=Gtk.Box(spacing=8);buttons.pack_start(button('New event',self.new),False,False,0)
        buttons.pack_end(button('Save event',self.save,'suggested-action'),False,False,0)
        self.body.pack_start(buttons,False,False,0);self.body.pack_start(self.status,False,False,0)
        self.calendar.connect('day-selected',lambda *_:self.refresh())
        self.calendar.connect('month-changed',lambda *_:self.mark())
        self.select_date(date.fromisoformat(selected) if selected else date.today())
        self.refresh()

    def day(self):
        year,month,day=self.calendar.get_date();return date(year,month+1,max(1,day))

    def select_date(self,value):
        self.calendar.select_month(value.month-1,value.year);self.calendar.select_day(value.day)

    def new(self,_button=None):
        self.event_id=None;self.title_entry.set_text('');self.time_entry.set_text('');self.notes.set_text('');self.status.set_text('');self.title_entry.grab_focus()

    def save(self,_button):
        try:
            event=self.store.save(self.title_entry.get_text(),self.day().isoformat(),self.time_entry.get_text(),self.notes.get_text(),self.event_id,colors()['accent'])
            self.event_id=event['id'];self.status.set_text('Event saved.');self.refresh()
        except (ValueError,OSError) as error:self.error(error)

    def edit(self,event):
        self.event_id=event['id'];self.title_entry.set_text(event['title']);self.time_entry.set_text(event.get('time',''));self.notes.set_text(event.get('notes',''))

    def delete(self,event):
        if not confirm(self,'Delete event?',event['title']):return
        try:self.store.delete(event['id']);self.new();self.refresh()
        except (ValueError,OSError) as error:self.error(error)

    def mark(self):
        self.calendar.clear_marks();year,month,_=self.calendar.get_date()
        try:
            for event in self.store.all():
                day=date.fromisoformat(event['date'])
                if day.year==year and day.month==month+1:self.calendar.mark_day(day.day)
        except (ValueError,OSError) as error:self.error(error)

    def refresh(self):
        self.mark();clear(self.events);self.day_label.set_text(self.day().strftime('%A, %d %B'))
        try:
            entries=[e for e in self.store.all() if e['date']==self.day().isoformat()]
            for event in entries:
                row=Gtk.Box(spacing=8);row.pack_start(label('● '+(event.get('time') or 'All day')+'  '+event['title']),True,True,0)
                row.pack_end(button('Delete',lambda _,e=event:self.delete(e),'danger'),False,False,0)
                row.pack_end(button('Edit',lambda _,e=event:self.edit(e)),False,False,0)
                self.events.pack_start(row,False,False,0)
            if not entries:self.events.pack_start(label('No events. Add one below.','muted'),False,False,0)
            self.events.show_all()
        except (ValueError,OSError) as error:self.error(error)


class BluetoothWindow(Window):
    def __init__(self,app):
        super().__init__(app,'Bluetooth','Manage paired devices, discover nearby devices and connect securely.',680,690)
        self.owned_scan=False;self.adapters=[];self.devices=[];self.signature=None;self.pending=False;self.updating=False;self.closed=False;self.manager_handlers=[]
        row=Gtk.Box(spacing=10);row.pack_start(label('Bluetooth power'),True,True,0)
        self.power=Gtk.Switch();self.power.connect('notify::active',lambda switch,_pspec:self.set_power(switch,switch.get_active()));row.pack_start(self.power,False,False,0)
        self.scan=button('Scan nearby',self.scan_clicked,'suggested-action');row.pack_end(self.scan,False,False,0)
        self.body.pack_start(row,False,False,0)
        self.body.pack_start(self.status,False,False,0)
        content=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=12)
        content.pack_start(label('PAIRED DEVICES','muted'),False,False,0)
        self.paired=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=7);content.pack_start(self.paired,False,False,0)
        content.pack_start(label('NEARBY / DISCOVERED','muted'),False,False,0)
        self.nearby=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=7);content.pack_start(self.nearby,False,False,0)
        self.body.pack_start(self.scroller(content,300),True,True,0)
        self.body.pack_end(label('Scanning stops automatically after 20 seconds. Forget removes the pairing from this computer.','muted'),False,False,0)
        self.connect('destroy',self.cleanup)
        try:
            self.manager=Gio.DBusObjectManagerClient.new_for_bus_sync(Gio.BusType.SYSTEM,Gio.DBusObjectManagerClientFlags.NONE,'org.bluez','/',None,None,None)
            for signal in ['object-added','object-removed','interface-proxy-properties-changed']:
                self.manager_handlers.append(self.manager.connect(signal,self.changed))
            self.refresh()
        except GLib.Error as error:
            self.error('Bluetooth service unavailable: '+error.message);self.scan.set_sensitive(False);self.power.set_sensitive(False)

    @staticmethod
    def prop(proxy,name,default=None):
        value=proxy.get_cached_property(name);return value.unpack() if value is not None else default

    def changed(self,*_args):
        if not self.closed and not self.pending:self.pending=True;GLib.timeout_add(100,self.refresh)

    def refresh(self):
        if self.closed:return False
        self.pending=False;self.adapters=[];self.devices=[]
        for obj in self.manager.get_objects():
            adapter=obj.get_interface('org.bluez.Adapter1');device=obj.get_interface('org.bluez.Device1')
            if adapter:self.adapters.append(adapter)
            if device:self.devices.append(device)
        if not self.adapters:
            self.error('No Bluetooth adapter is available.');self.scan.set_sensitive(False);self.power.set_sensitive(False);return False
        self.adapter=self.adapters[0];powered=self.prop(self.adapter,'Powered',False)
        self.updating=True
        self.power.set_active(powered);self.scan.set_sensitive(powered)
        self.updating=False
        discovering=self.prop(self.adapter,'Discovering',False)
        self.scan.set_label('Stop scan' if self.owned_scan else 'Scan nearby')
        if discovering:self.status.set_text('Scanning for nearby devices…')
        signature=tuple(sorted((d.get_object_path(),self.prop(d,'Alias','Bluetooth device'),self.prop(d,'Paired',False),self.prop(d,'Connected',False)) for d in self.devices))
        if signature==self.signature:return False
        self.signature=signature;clear(self.paired);clear(self.nearby)
        paired_count=near_count=0
        for device in sorted(self.devices,key=lambda d:self.prop(d,'Alias','').lower()):
            if self.prop(device,'Adapter')!=self.adapter.get_object_path():continue
            paired=self.prop(device,'Paired',False);connected=self.prop(device,'Connected',False)
            row=Gtk.Box(spacing=8)
            details=self.prop(device,'Alias','Bluetooth device')+'\n'+('Connected' if connected else ('Paired' if paired else 'Available'))
            row.pack_start(label(details),True,True,0)
            if paired:
                row.pack_end(button('Forget',lambda _,d=device:self.forget(d),'danger'),False,False,0)
                row.pack_end(button('Disconnect' if connected else 'Connect',lambda _,d=device,c=connected:self.call(d,'Disconnect' if c else 'Connect')),False,False,0)
                self.paired.pack_start(row,False,False,0);paired_count+=1
            else:
                row.pack_end(button('Pair',lambda _,d=device:self.call(d,'Pair',paired_device=d)),False,False,0)
                self.nearby.pack_start(row,False,False,0);near_count+=1
        if not paired_count:self.paired.pack_start(label('No paired devices.','muted'),False,False,0)
        if not near_count:self.nearby.pack_start(label('Scan to discover nearby devices.','muted'),False,False,0)
        self.paired.show_all();self.nearby.show_all();return False

    def call(self,proxy,method,parameters=None,paired_device=None):
        self.status.set_text(method+'…')
        def done(source,result):
            try:
                source.call_finish(result)
                if self.closed:return
                self.status.set_text('Done.');self.signature=None;self.refresh()
                if paired_device:self.call(paired_device,'Connect')
            except GLib.Error as error:
                if self.closed:return
                if method=='StartDiscovery':self.owned_scan=False;self.scan.set_label('Scan nearby')
                self.error(error.message)
        proxy.call(method,parameters,Gio.DBusCallFlags.NONE,30000,None,done)

    def set_power(self,_switch,state):
        if self.updating:return False
        if not hasattr(self,'adapter'):return False
        connection=self.manager.get_connection()
        def done(source,result):
            try:source.call_finish(result);self.status.set_text('Bluetooth enabled.' if state else 'Bluetooth disabled.')
            except GLib.Error as error:self.error(error.message);self.refresh()
        connection.call('org.bluez',self.adapter.get_object_path(),'org.freedesktop.DBus.Properties','Set',
                        GLib.Variant('(ssv)',('org.bluez.Adapter1','Powered',GLib.Variant('b',state))),
                        None,Gio.DBusCallFlags.NONE,10000,None,done)
        return True

    def scan_clicked(self,_button):
        if not hasattr(self,'adapter'):return
        if self.owned_scan:
            self.call(self.adapter,'StopDiscovery');self.owned_scan=False;self.scan.set_label('Scan nearby')
        else:
            self.call(self.adapter,'StartDiscovery');self.owned_scan=True;self.scan.set_label('Stop scan')
            GLib.timeout_add_seconds(20,self.stop_scan)

    def stop_scan(self):
        if not self.closed and self.owned_scan and hasattr(self,'adapter'):
            self.call(self.adapter,'StopDiscovery');self.owned_scan=False;self.scan.set_label('Scan nearby')
        return False

    def forget(self,device):
        name=self.prop(device,'Alias','this device')
        if confirm(self,'Forget '+name+'?','You will need to pair this device again before using it.'):
            self.call(self.adapter,'RemoveDevice',GLib.Variant('(o)',(device.get_object_path(),)))

    def cleanup(self,*_args):
        self.closed=True
        if self.owned_scan and hasattr(self,'adapter'):
            self.adapter.call('StopDiscovery',None,Gio.DBusCallFlags.NONE,5000,None,None)
        self.owned_scan=False
        if hasattr(self,'manager'):
            for handler in self.manager_handlers:self.manager.disconnect(handler)


class Application(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='org.rice.DesktopTools',flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.windows_by_mode={}

    def do_startup(self):
        Gtk.Application.do_startup(self);theme()

    def do_command_line(self,command):
        parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['bluetooth','binds','events']);parser.add_argument('--date')
        args=parser.parse_args(command.get_arguments()[1:])
        window=self.windows_by_mode.get(args.mode)
        if window:window.present();return 0
        window={'bluetooth':lambda:BluetoothWindow(self),'binds':lambda:BindWindow(self),'events':lambda:EventWindow(self,args.date)}[args.mode]()
        self.windows_by_mode[args.mode]=window
        window.connect('destroy',lambda *_:self.windows_by_mode.pop(args.mode,None))
        window.show_all();window.present();return 0


if __name__=='__main__':
    GLib.set_prgname('rice-desktop');Gdk.set_program_class('RiceTools')
    raise SystemExit(Application().run(sys.argv))
