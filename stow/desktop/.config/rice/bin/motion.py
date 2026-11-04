#!/usr/bin/env python3
"""Short input-transparent transitions; no screenshot files and no idle polling."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time

from motion_client import request, socket_path


def easing(progress):
    progress=max(0.,min(1.,progress))
    return 1-(1-progress)**3


def focus_command(target,send=False):
    if not (target.isdecimal() and 1<=int(target)<=10 or target in ('prev.local','next.local')):
        raise ValueError('Invalid desktop selector')
    return ['bspc','node','-d',target,'--follow'] if send else ['bspc','desktop','-f',target]


def serve():
    import gi
    gi.require_version('Gtk','3.0');gi.require_version('GdkX11','3.0')
    from gi.repository import Gtk,Gdk,GdkX11,GLib
    import cairo

    class Overlay(Gtk.Window):
        def __init__(self,pixbuf,rect,direction,duration):
            super().__init__(type=Gtk.WindowType.POPUP)
            self.started=None;self.duration=duration;self.direction=direction;self.progress=0.;self.pixbuf=pixbuf
            self.set_wmclass('rice-motion','RiceMotion')
            self.set_app_paintable(True);self.set_decorated(False)
            self.set_accept_focus(False);self.set_focus_on_map(False)
            self.set_skip_taskbar_hint(True);self.set_skip_pager_hint(True);self.set_keep_above(True)
            visual=self.get_screen().get_rgba_visual()
            if visual:self.set_visual(visual)
            self.move(rect[0],rect[1]);self.set_default_size(rect[2],rect[3])
            self.connect('draw',self.draw_frame)
            self.realize();self.get_window().input_shape_combine_region(cairo.Region(),0,0)
            self.show_all();self.get_display().flush()

        def draw_frame(self,_widget,context):
            context.set_operator(cairo.OPERATOR_SOURCE);context.set_source_rgba(0,0,0,0);context.paint()
            context.set_operator(cairo.OPERATOR_OVER)
            offset=-self.direction*min(80,self.pixbuf.get_width()*.06)*easing(self.progress)
            Gdk.cairo_set_source_pixbuf(context,self.pixbuf,offset,0)
            context.paint_with_alpha(1-easing(self.progress));return False

        def start(self):
            self.started=time.monotonic();self.add_tick_callback(self.tick)
            return False

        def tick(self,_widget,_clock):
            self.progress=min(1.,(time.monotonic()-self.started)/self.duration)
            self.queue_draw()
            if self.progress>=1:
                self.hide();return False
            return True

    class Service:
        def __init__(self):
            self.overlay=None;self.pending=0;self.generation=0;self.token=None
            self.display=Gdk.Display.get_default();self.root=Gdk.get_default_root_window()
            self.server=socket.socket(socket.AF_UNIX);self.server.bind(str(socket_path()))
            os.chmod(socket_path(),0o600);self.server.listen(8);self.server.setblocking(False)
            GLib.io_add_watch(self.server.fileno(),GLib.IO_IN,self.accept)

        def cancel(self):
            self.generation+=1;self.token=None
            if self.pending:GLib.source_remove(self.pending);self.pending=0
            if self.overlay:
                self.overlay.destroy();self.overlay=None

        def capture(self,rect,direction=1,duration=.18):
            # Let the actual window action proceed immediately without a compositor.
            if not self.display.supports_composite() or not self.root.get_screen().is_composited():return False
            pixbuf=Gdk.pixbuf_get_from_window(self.root,*rect)
            if not pixbuf:return False
            self.cancel();self.overlay=Overlay(pixbuf,rect,direction,duration)
            # A lost commit must never leave a stale screenshot on the screen.
            generation=self.generation
            def expire():
                if generation==self.generation:
                    self.pending=0;self.cancel()
                return False
            self.pending=GLib.timeout_add(450,expire)
            return True

        def accept(self,_fd,_condition):
            conn,_=self.server.accept();conn.setblocking(False);buffer=bytearray()
            def read(_fd,condition):
                try:
                    part=conn.recv(4096)
                    if not part:conn.close();return False
                    buffer.extend(part)
                    if len(buffer)>4096:conn.close();return False
                    if b'\n' not in buffer:return True
                    message=json.loads(buffer.split(b'\n')[0]);self.handle(message,conn)
                except (OSError,ValueError,KeyError,TypeError,GLib.Error,subprocess.SubprocessError) as error:
                    print('motion:',error,file=sys.stderr,flush=True)
                    self.cancel()
                    try:conn.sendall(b'error\n')
                    except OSError:pass
                    conn.close()
                return False
            GLib.io_add_watch(conn.fileno(),GLib.IO_IN|GLib.IO_HUP,read)
            return True

        def reply(self,connection):
            try:connection.sendall(b'ok\n')
            except OSError:pass
            connection.close();return False

        def handle(self,message,connection):
            if not isinstance(message,dict):raise ValueError('Invalid motion request')
            operation=message.get('op')
            if operation=='cancel':self.cancel();self.reply(connection);return
            if operation=='commit':
                if self.overlay and message.get('token')==self.token:self.overlay.start()
                self.reply(connection);return
            if operation=='prepare':
                xid=int(message['window'])
                window=GdkX11.X11Window.foreign_new_for_display(self.display,xid)
                if not window:raise ValueError('Window is unavailable')
                _,x,y=window.get_origin();_,_,width,height=window.get_geometry()
                if message.get('tabbar'):height=min(64,height)
                if not self.capture((x,y,width,height),int(message.get('direction',1)),.14):
                    connection.sendall(b'error\n');connection.close();return
                self.token=message.get("token")
                GLib.timeout_add(50,self.reply,connection);return
            if operation=='focus':
                target=str(message['target']);command=focus_command(target,message.get('send',False))
                tree=json.loads(subprocess.check_output(['bspc','wm','-d'],text=True,timeout=1))
                monitor=next(m for m in tree['monitors'] if m['id']==tree['focusedMonitorId'])
                if target.isdecimal():
                    monitor=next(m for m in tree['monitors'] if any(d['name']==target for d in m['desktops']))
                visible=next(d for d in monitor['desktops'] if d['id']==monitor['focusedDesktopId'])
                animate=(target!=visible['name'] and not message.get('send',False))
                rect=monitor['rectangle'];left=monitor['padding']['left'];top=monitor['padding']['top']
                area=(rect['x']+left,rect['y']+top,rect['width']-left-monitor['padding']['right'],rect['height']-top-monitor['padding']['bottom'])
                direction=-1 if target=='prev.local' or (target.isdecimal() and int(target)<int(visible['name'])) else 1
                captured=animate and self.capture(area,direction)
                if not captured:self.cancel()
                # Accept ownership before executing, preventing fallback duplicate actions.
                self.reply(connection)
                generation=self.generation
                def switch():
                    if generation!=self.generation:return False
                    try:subprocess.run(command,check=True,timeout=1,stdout=subprocess.DEVNULL)
                    except subprocess.SubprocessError as error:print('motion:',error,file=sys.stderr,flush=True)
                    if self.overlay:self.overlay.start()
                    return False
                if captured:GLib.timeout_add(50,switch)
                else:switch()
                return
            raise ValueError('Unknown motion operation')

    path=socket_path();path.parent.mkdir(mode=0o700,parents=True,exist_ok=True)
    with (path.parent/'rice-motion.lock').open('a') as lock:
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return
        path.unlink(missing_ok=True)
        Gdk.set_program_class('RiceMotion')
        service=Service()
        try:Gtk.main()
        finally:service.cancel();service.server.close();path.unlink(missing_ok=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serve',action='store_true');parser.add_argument('--cancel',action='store_true')
    parser.add_argument('--focus');parser.add_argument('--send',action='store_true')
    args=parser.parse_args()
    if args.serve:serve()
    elif args.cancel:request('cancel')
    elif args.focus:
        command=focus_command(args.focus,args.send)
        if not request('focus',target=args.focus,send=args.send):subprocess.run(command,check=True)
    else:parser.error('choose --serve, --cancel or --focus')

if __name__=='__main__':main()
