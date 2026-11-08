"""Theme-aware animation preferences dialog with a live, unsaved preview."""
from copy import deepcopy
import json
import os
from pathlib import Path
import math
import threading
import time
import gi
gi.require_version('Gtk','3.0')
from gi.repository import Gtk,Gdk,GLib
from desktop_ui import Window,label,button,colors,theme
import animation_settings as settings


class AnimationWindow(Window):
    def __init__(self,app):
        super().__init__(app,'Animation settings','Shape how your desktop moves. Changes take effect when you apply them.',820,850)
        self.widgets={};self.busy=False;self.loading=False;self.preview_started=None;self.preview_source=0
        self.backend=settings.detect();self.engine=self.backend['engine'];self.original=settings.load()
        self.body.set_spacing(10)
        self.get_style_context().add_class('animation-settings')
        c=colors();provider=Gtk.CssProvider()
        css="""
        .animation-settings notebook, .animation-settings notebook stack {background: SURFACE; border-color: OVERLAY; border-radius: 12px;}
        .animation-settings notebook header {background: BG; border-color: OVERLAY;}
        .animation-settings notebook tab {background: transparent; padding: 9px 12px; color: DIM;}
        .animation-settings notebook tab:checked {background: OVERLAY; color: FG; border-radius: 8px;}
        .animation-settings switch:checked {background: ACCENT; border-color: ACCENT;}
        .animation-settings spinbutton {background: BG; color: FG; border-color: OVERLAY; border-radius: 9px;}
        """
        for token,key in [('SURFACE','surface'),('OVERLAY','overlay'),('ACCENT','accent'),('DIM','fg_dim'),('BG','bg'),('FG','fg')]:css=css.replace(token,c[key])
        provider.load_from_data(css.encode());Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),provider,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION+1)

        badge=Gtk.Box(spacing=12)
        self.badge=label('60 FPS','title');badge.pack_start(self.badge,False,False,0)
        badge.pack_start(label({'ftlabs':'FT-Labs spring engine','modern':'Picom native animation engine','basic':'Compatibility engine · fade only'}[self.engine]+' · '+self.backend['version'],'muted'),True,True,0)
        self.body.pack_start(badge,False,False,0)
        self.preview=Gtk.DrawingArea();self.preview.set_size_request(-1,112);self.preview.connect('draw',self.draw_preview)
        self.body.pack_start(self.preview,False,False,0)
        self.body.pack_start(label('Preview uses unsaved settings. FPS is a ceiling; monitor refresh and rendering cost can lower the actual rate.','muted'),False,False,0)
        notebook=Gtk.Notebook();self.body.pack_start(notebook,True,True,0)
        general=self.page(notebook,'General')
        self.switch(general,'enabled','Enable animations','One switch for native effects, workspace and terminal transitions.')
        self.switch(general,'limit_fps','Limit frame rate','Caps composed frames without changing monitor resolution or refresh.')
        self.number(general,'fps','Maximum FPS',15,240,1,'Default: 60 FPS')
        self.switch(general,'vsync','VSync','Synchronize presentation to reduce tearing.')
        self.switch(general,'fading','Fade windows','Blend windows in and out.')
        self.number(general,'fade_ms','Fade duration',40,1000,10,'Milliseconds')
        row=Gtk.Box(spacing=8);row.pack_start(label('Quick preset'),True,True,0)
        preset=Gtk.ComboBoxText();preset.append('custom','Custom');preset.set_active_id('custom')
        for key,title in [('balanced','Balanced · 60 FPS'),('subtle','Subtle'),('snappy','Snappy'),('cinematic','Cinematic')]:preset.append(key,title)
        preset.connect('changed',self.preset);row.pack_end(preset,False,False,0);general.pack_start(row,False,False,8)
        native=self.page(notebook,'Window effects')
        native.pack_start(label('Opening, closing and popup effects use the compositor. Native motion is unavailable in compatibility mode.','muted'),False,False,0)
        for event,title in [('open','Open / show'),('close','Close / hide'),('popup','Popup / dialog')]:
            self.switch(native,event+'_enabled',title,'Enable this event')
            choices=settings.FT_TYPES if self.engine=='ftlabs' else settings.MODERN_TYPES
            self.combo(native,event+'_type','Effect',choices)
            spin=self.number(native,event+'_ms','Duration',60,1000,10,'Milliseconds · native presets')
            spin.set_sensitive(self.engine=='modern')
        if self.engine=='ftlabs':native.pack_start(label('FT-Labs timing follows the spring controls in Advanced. Desktop and terminal durations are configured separately.','muted'),False,False,0)
        else:self.number(native,'geometry_ms','Resize / move duration',60,1000,10,'Milliseconds')
        native.set_sensitive(self.engine!='basic')
        desktop=self.page(notebook,'Workspaces & tabs')
        for event,title in [('workspace','Workspace transitions'),('tabs','Kitty tabs and splits')]:
            self.switch(desktop,event+'_enabled',title,'Smooth transitions while keeping normal input and focus.')
            self.combo(desktop,event+'_type','Transition',settings.MOTION_TYPES)
            self.number(desktop,event+'_ms','Duration',60,700,10,'Milliseconds')
        advanced=self.page(notebook,'Advanced')
        advanced.pack_start(label('Spring controls are specific to FT-Labs. Higher stiffness settles faster; damping reduces oscillation.','muted'),False,False,0)
        for key,title,low,high,step in [('stiffness','Window stiffness',20,800,10),('workspace_stiffness','Native tag stiffness',20,800,10),('mass','Window mass',.1,3,.1),('damping','Damping',5,80,1)]:
            self.number(advanced,key,title,low,high,step)
        self.switch(advanced,'clamping','Clamp spring motion','Prevent overshoot. May change the spring feel.')
        advanced.set_sensitive(self.engine=='ftlabs')
        self.body.pack_start(self.status,False,False,0)
        actions=Gtk.Box(spacing=8)
        actions.pack_start(button('Defaults',self.defaults),False,False,0)
        self.undo=button('Undo last apply',self.undo_apply);actions.pack_start(self.undo,False,False,0)
        self.preview_button=button('Preview',self.start_preview);actions.pack_end(self.preview_button,False,False,0)
        self.apply_button=button('Apply',self.apply_clicked,'suggested-action');actions.pack_end(self.apply_button,False,False,0)
        self.body.pack_end(actions,False,False,0);self.actions=actions
        self.fill(self.original)
        if self.engine=='modern':
            for key in ('fading','fade_ms'):self.widgets[key].set_sensitive(False);self.widgets[key].set_tooltip_text('Native presets control their own fading')
        self.connect('destroy',self.cleanup)
        self.connect('delete-event',lambda *_:self.busy)

    def page(self,notebook,title):
        box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=10,margin=16)
        scroll=Gtk.ScrolledWindow();scroll.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_height(240);scroll.add(box);notebook.append_page(scroll,Gtk.Label(label=title));return box

    def row(self,box,title,subtitle=''):
        row=Gtk.Box(spacing=14);text=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=3)
        text.pack_start(label(title),False,False,0)
        if subtitle:text.pack_start(label(subtitle,'muted'),False,False,0)
        row.pack_start(text,True,True,0);box.pack_start(row,False,False,3);return row

    def switch(self,box,key,title,subtitle=''):
        widget=Gtk.Switch(valign=Gtk.Align.CENTER);widget.connect('notify::active',self.changed)
        self.row(box,title,subtitle).pack_end(widget,False,False,0);self.widgets[key]=widget;return widget

    def number(self,box,key,title,low,high,step,subtitle=''):
        widget=Gtk.SpinButton.new_with_range(low,high,step);widget.set_numeric(True);widget.set_digits(1 if step<1 else 0)
        widget.connect('value-changed',self.changed)
        self.row(box,title,subtitle).pack_end(widget,False,False,0);self.widgets[key]=widget;return widget

    def combo(self,box,key,title,choices):
        widget=Gtk.ComboBoxText()
        for value in choices:widget.append(value,value.replace('-',' ').title())
        widget.connect('changed',self.changed);self.row(box,title).pack_end(widget,False,False,0)
        self.widgets[key]=widget;return widget

    def fill(self,value):
        self.loading=True;self.draft=deepcopy(settings.validate(value))
        for key,widget in self.widgets.items():
            v=self.draft[key]
            if isinstance(widget,Gtk.Switch):widget.set_active(v)
            elif isinstance(widget,Gtk.SpinButton):widget.set_value(v)
            else:
                if self.engine=='modern' and key in ('open_type','close_type','popup_type'):v=settings.modern_type(v,key=='close_type')[0] or 'appear'
                widget.set_active_id(v)
        self.loading=False;self.changed()

    def values(self):
        value=deepcopy(self.draft)
        for key,widget in self.widgets.items():
            if isinstance(widget,Gtk.Switch):value[key]=widget.get_active()
            elif isinstance(widget,Gtk.SpinButton):value[key]=widget.get_value()
            elif widget.get_active_id():value[key]=widget.get_active_id()
        return settings.validate(value)

    def changed(self,*_args):
        if self.loading:return
        value=self.values();self.badge.set_text(str(value['fps'])+' FPS' if value['limit_fps'] else 'Uncapped')
        self.widgets['fps'].set_sensitive(value['limit_fps']);self.preview.queue_draw()
        self.status.set_text('Unsaved changes' if value!=self.original else 'Settings are up to date.')

    def defaults(self,_button):self.fill(settings.DEFAULTS)

    def preset(self,combo):
        key=combo.get_active_id()
        if not key or key=='custom':return
        value=deepcopy(settings.DEFAULTS)
        if key=='subtle':value.update(open_type='zoom',close_type='zoom',workspace_type='fade',tabs_type='fade',stiffness=350.,damping=30.)
        elif key=='snappy':value.update(stiffness=450.,damping=32.,workspace_ms=120,tabs_ms=90,fade_ms=90)
        elif key=='cinematic':value.update(open_type='fly-in',close_type='minimize',workspace_ms=360,tabs_ms=240,stiffness=160.,damping=20.)
        self.fill(value);self.start_preview()

    def start_preview(self,_button=None):
        if self.preview_source:GLib.source_remove(self.preview_source)
        self.preview_started=time.monotonic()
        fps=self.values()['fps'] if self.values()['limit_fps'] else 120
        self.preview_source=GLib.timeout_add(math.ceil(1000/fps),self.preview_tick)

    def preview_tick(self):
        self.preview.queue_draw()
        if time.monotonic()-self.preview_started>1.2:self.preview_source=0;self.preview_started=None;return False
        return True

    def draw_preview(self,widget,context):
        c=colors();width=widget.get_allocated_width();height=widget.get_allocated_height()
        def rgb(text):return tuple(int(text[i:i+2],16)/255 for i in (1,3,5))
        context.set_source_rgb(*rgb(c['surface']));context.rectangle(0,0,width,height);context.fill()
        progress=1.
        if self.preview_started and self.values()['enabled']:
            duration=max(.06,self.values()['open_ms']/1000)
            progress=min(1.,(time.monotonic()-self.preview_started)/duration)
        eased=1-(1-progress)**3;effect=self.values()['open_type']
        x=width/2-85;y=height/2-36;scale=1.;opacity=eased
        if 'slide' in effect or 'fly' in effect:
            if 'left' in effect:x+=90*(1-eased)
            elif 'right' in effect:x-=90*(1-eased)
            elif 'down' in effect:y-=60*(1-eased)
            else:y+=60*(1-eased)
        elif effect in ('zoom','appear','maximize','minimize'):scale=.7+.3*eased
        elif 'squeeze' in effect:scale=max(.05,eased)
        context.save();context.translate(x+85,y+36);context.scale(scale,scale);context.translate(-85,-36)
        context.set_source_rgba(*rgb(c['accent']),opacity);context.rectangle(0,0,170,72);context.fill()
        context.set_source_rgba(1,1,1,opacity);context.select_font_face('Sans');context.set_font_size(14);context.move_to(22,40);context.show_text('Sample window');context.restore()
        return False

    def apply_clicked(self,_button=None):
        if self.busy:return
        value=self.values();self.busy=True;self.actions.set_sensitive(False);self.status.set_text('Applying and checking the compositor…')
        def work():
            try:backup=settings.apply(value);GLib.idle_add(self.finished,value,str(backup),None)
            except Exception as error:GLib.idle_add(self.finished,None,None,str(error))
        threading.Thread(target=work,daemon=True).start()

    def finished(self,value,backup,error):
        if not self.get_realized():return False
        self.busy=False;self.actions.set_sensitive(True)
        if error:self.error(error)
        else:
            self.original=value;self.fill(value);self.status.set_text('Applied · backup saved.');self.start_preview()
        return False

    def undo_apply(self,_button):
        state=os.environ.get('XDG_STATE_HOME') or str(Path.home()/'.local/state')
        paths=sorted(Path(state).glob('rice/animation-backups/*/settings.json'))
        if not paths:self.error('No previous animation settings yet.');return
        try:self.fill(json.loads(paths[-1].read_text()));self.apply_clicked()
        except (ValueError,OSError) as error:self.error(error)

    def cleanup(self,*_args):
        if self.preview_source:GLib.source_remove(self.preview_source);self.preview_source=0
