#!/usr/bin/env python3
"""Validated animation preferences, generated compositor config and safe application."""
import argparse
import ctypes
from copy import deepcopy
from datetime import datetime
import fcntl
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
FT_TYPES=('none','fly-in','zoom','slide-up','slide-down','slide-left','slide-right',
          'slide-out','slide-in','slide-out-center','slide-in-center','minimize','maximize','squeeze','squeeze-bottom')
MODERN_TYPES=('appear','disappear','fly-in','fly-out','slide-in','slide-out')
MOTION_TYPES=('slide-fade','fade','slide','zoom')
DEFAULTS=dict(enabled=True,fps=60,limit_fps=True,vsync=True,fading=True,fade_ms=140,
              open_enabled=True,close_enabled=True,popup_enabled=True,
              open_type='slide-up',close_type='slide-down',popup_type='slide-up',
              open_ms=180,close_ms=150,popup_ms=160,geometry_ms=200,
              workspace_enabled=True,workspace_type='slide-fade',workspace_ms=180,
              tabs_enabled=True,tabs_type='fade',tabs_ms=140,
              stiffness=400.,workspace_stiffness=400.,mass=.5,damping=20.,clamping=True)
BOOL_KEYS=tuple(k for k,v in DEFAULTS.items() if isinstance(v,bool))
BOUNDS={'fps':(15,240),'fade_ms':(40,1000),'open_ms':(60,1000),'close_ms':(60,1000),
        'popup_ms':(60,1000),'geometry_ms':(60,1000),'workspace_ms':(60,700),'tabs_ms':(60,700),
        'stiffness':(20,800),'workspace_stiffness':(20,800),'mass':(.1,3),'damping':(5,80)}


def settings_path():return Path.home()/'.config/rice/animations.json'
def recovery_active():return (settings_path().parent/'compositor-safe-mode').exists()
def cache_dir():return Path(os.environ.get('XDG_CACHE_HOME') or str(Path.home()/'.cache'))/'rice/animations'


def validate(value):
    if not isinstance(value,dict):raise ValueError('Invalid animation preferences')
    if set(value)-set(DEFAULTS):raise ValueError('Unknown animation preference')
    result={**DEFAULTS,**value}
    for key in BOOL_KEYS:
        if type(result[key]) is not bool:raise ValueError(key+' must be enabled or disabled')
    for key,(low,high) in BOUNDS.items():
        v=result[key]
        if type(v) not in (int,float) or not low<=v<=high or (key.endswith('_ms') or key=='fps') and int(v)!=v:
            raise ValueError(f'{key} must be between {low} and {high}')
        result[key]=int(v) if key.endswith('_ms') or key=='fps' else float(v)
    for key in ('open_type','close_type','popup_type'):
        if result[key] not in FT_TYPES+MODERN_TYPES:raise ValueError('Unsupported animation type')
    for key in ('workspace_type','tabs_type'):
        if result[key] not in MOTION_TYPES:raise ValueError('Unsupported desktop transition')
    return result


def load():
    path=settings_path()
    return validate(json.loads(path.read_text())) if path.exists() else deepcopy(DEFAULTS)


def compositor_active():
    """Query the X11 compositor selection, not merely a potentially stale PID."""
    try:
        x=ctypes.CDLL('libX11.so.6')
        x.XOpenDisplay.argtypes=[ctypes.c_char_p];x.XOpenDisplay.restype=ctypes.c_void_p
        x.XDefaultScreen.argtypes=[ctypes.c_void_p];x.XDefaultScreen.restype=ctypes.c_int
        x.XInternAtom.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_int];x.XInternAtom.restype=ctypes.c_ulong
        x.XGetSelectionOwner.argtypes=[ctypes.c_void_p,ctypes.c_ulong];x.XGetSelectionOwner.restype=ctypes.c_ulong
        x.XCloseDisplay.argtypes=[ctypes.c_void_p]
        display=x.XOpenDisplay(None)
        if not display:return False
        try:
            atom=x.XInternAtom(display,('_NET_WM_CM_S'+str(x.XDefaultScreen(display))).encode(),0)
            return bool(x.XGetSelectionOwner(display,atom))
        finally:x.XCloseDisplay(display)
    except OSError:return False


def detect():
    result=subprocess.run(['picom','--help'],capture_output=True,text=True,timeout=3)
    help=result.stdout+result.stderr
    version=subprocess.check_output(['picom','--version'],text=True,timeout=3).strip()
    if '--animation-stiffness-in-tag' in help:engine='ftlabs'
    else:
        match=re.search(r'v?(\d+)\.',version)
        engine='modern' if match and int(match[1])>=12 else 'basic'
    return dict(engine=engine,version=version)


def base_path(engine):
    return Path.home()/'.config/picom'/dict(ftlabs='picom-ftlabs.conf',modern='picom.conf',basic='picom-basic.conf')[engine]


def scalar(text,key,value):
    literal=json.dumps(value) if isinstance(value,(str,bool)) else str(value)
    pattern=r'(?m)^'+re.escape(key)+r'[ \t]*=[^;\n]*;'
    if re.search(pattern,text):return re.sub(pattern,lambda _m:key+' = '+literal+';',text)
    return text+'\n'+key+' = '+literal+';\n'


def modern_type(value,closing=False):
    if value in MODERN_TYPES:return value, None
    if value in ('none',):return None,None
    if value.startswith('slide-') and value.split('-')[-1] in ('up','down','left','right'):
        return 'slide-out' if closing else 'slide-in',value.split('-')[-1]
    if value=='fly-in':return 'fly-out' if closing else 'fly-in','up'
    return 'disappear' if closing else 'appear',None


def render(text,engine,preferences):
    s=validate(preferences)
    text=scalar(text,'vsync',s['vsync'])
    text=scalar(text,'fading',s['enabled'] and s['fading']) if engine!='modern' else text
    if engine!='modern':
        step=min(1.,max(.01,8./s['fade_ms']))
        for key,value in [('fade-in-step',step),('fade-out-step',step),('fade-delta',8)]:text=scalar(text,key,value)
    if engine=='ftlabs':
        text=scalar(text,'animations',s['enabled'])
        for event,key in [('open','open-window'),('close','unmap-window'),('popup','transient-window')]:
            value=s[event+'_type'] if s[event+'_enabled'] else 'none'
            if value not in FT_TYPES:raise ValueError('This Picom build requires an FT-Labs effect')
            text=scalar(text,'animation-for-'+key,value)
        for key,value in [('animation-stiffness-in-tag',s['stiffness']),('animation-stiffness-tag-change',s['workspace_stiffness']),('animation-window-mass',s['mass']),('animation-dampening',s['damping']),('animation-clamping',s['clamping'])]:text=scalar(text,key,value)
    elif engine=='modern':
        scripts=[]
        if s['enabled']:
            for event,triggers in [('open',['open','show']),('close',['close','hide'])]:
                if not s[event+'_enabled']:continue
                preset,direction=modern_type(s[event+'_type'],event=='close')
                if preset:
                    script={'triggers':triggers,'preset':preset,'duration':s[event+'_ms']/1000}
                    if direction:script['direction']=direction
                    if preset in ('appear','disappear'):script['scale']=.94
                    scripts.append(script)
            scripts.append({'triggers':['geometry'],'preset':'geometry-change','duration':s['geometry_ms']/1000})
        block='animations = (\n'+',\n'.join('  { '+ ' '.join(k+' = '+json.dumps(v)+';' for k,v in item.items())+' }' for item in scripts)+'\n);'
        pattern=r'(?ms)^animations\s*=\s*\(.*?^\);'
        if not re.search(pattern,text):raise ValueError('Cannot locate the native animation block; original config retained')
        text=re.sub(pattern,lambda _:block,text,count=1)
        popup_preset,direction=modern_type(s['popup_type'])
        popup_script={'triggers':['open','show']}
        if s['enabled'] and s['popup_enabled'] and popup_preset:
            popup_script.update(preset=popup_preset,duration=s['popup_ms']/1000)
            if direction:popup_script['direction']=direction
            if popup_preset in ('appear','disappear'):popup_script['scale']=.94
        rule='  { match = "(window_type = \'dialog\' || window_type = \'popup_menu\' || window_type = \'dropdown_menu\') && class_g != \'i3lock\' && class_g != \'RiceMotion\'"; animations = ({ '+ ' '.join(k+' = '+json.dumps(v)+';' for k,v in popup_script.items())+' }); }'
        rule_pattern=r'(?ms)^rules\s*=\s*\(.*?^\);'
        match=re.search(rule_pattern,text)
        if not match:raise ValueError('Cannot locate the native window rules')
        original=match.group(0);updated=original[:-2].rstrip()+',\n'+rule+'\n);'
        text=text[:match.start()]+updated+text[match.end():]
    return '# Generated from your base Picom config; preferences: ~/.config/rice/animations.json\n# Frame ceiling: '+str(s['fps'])+' FPS; enabled: '+str(s['limit_fps'])+'\n'+text


def atomic_write(path,text):
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.animation-',dir=path.parent)
    try:
        with os.fdopen(fd,'w') as f:f.write(text)
        os.replace(name,path)
    finally:Path(name).unlink(missing_ok=True)


def limiter_library():
    source=HERE.parent/'lib/picom-frame-limit.c'
    digest=hashlib.sha256(source.read_bytes()+platform.machine().encode()).hexdigest()[:16]
    directory=cache_dir();directory.mkdir(parents=True,exist_ok=True)
    output=directory/('frame-limit-'+digest+'.so')
    with (directory/'build.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        if not output.exists():
            compiler=shutil.which('cc')
            if not compiler:raise RuntimeError('The FPS limiter needs a C compiler (package gcc)')
            temp=directory/(output.name+'.tmp')
            try:
                subprocess.run([compiler,'-shared','-fPIC','-O2','-Wall','-Wextra','-Werror',str(source),'-o',str(temp),'-ldl'],check=True,capture_output=True,text=True,timeout=30)
                os.replace(temp,output)
            finally:temp.unlink(missing_ok=True)
    return output


def prepare(base,preferences=None):
    s=load() if preferences is None else validate(preferences)
    engine='ftlabs' if base.name=='picom-ftlabs.conf' else 'modern' if base.name=='picom.conf' else 'basic'
    text=render(base.read_text(),engine,s)
    if s['limit_fps'] and not re.search(r'(?m)^backend\s*=\s*"(?:glx|egl)"',text):
        raise ValueError('The FPS ceiling requires the GLX or EGL backend')
    library=limiter_library() if s['limit_fps'] else None
    output=cache_dir()/(base.stem+'-'+hashlib.sha256(text.encode()).hexdigest()[:16]+'.conf')
    if not output.exists():atomic_write(output,text)
    env=os.environ.copy()
    env.pop('RICE_PICOM_FPS',None)
    if library:
        env['RICE_PICOM_FPS']=str(s['fps'])
        env['LD_PRELOAD']=str(library)+(':'+env['LD_PRELOAD'] if env.get('LD_PRELOAD') else '')
    return output,env


def restart():
    result=subprocess.run([str(HERE/'picom-launch.sh'),'--restart'],capture_output=True,text=True,timeout=15)
    if result.returncode:raise RuntimeError(result.stderr.strip() or 'Compositor did not start; previous settings will be restored')
    # Do not accept the launcher's compatibility fallback as a successful apply.
    base=base_path(detect()['engine']);text=render(base.read_text(),detect()['engine'],load())
    expected=cache_dir()/(base.stem+'-'+hashlib.sha256(text.encode()).hexdigest()[:16]+'.conf')
    alive=False
    for proc in Path('/proc').glob('[0-9]*'):
        try:args=(proc/'cmdline').read_bytes().split(b'\0')
        except OSError:continue
        if args and Path(os.fsdecode(args[0])).name=='picom' and os.fsencode(expected) in args:alive=True
    if not alive or not compositor_active():raise RuntimeError('The selected animation configuration was not activated')


def apply(preferences):
    if recovery_active():raise RuntimeError('Display recovery mode is active. Animation changes are paused to keep your desktop visible.')
    s=validate(preferences)
    path=settings_path();state=Path(os.environ.get('XDG_STATE_HOME') or str(Path.home()/'.local/state'))/'rice'
    state.mkdir(parents=True,exist_ok=True)
    with (state/'animation-settings.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        # Compile and render before touching the running compositor.
        base=base_path(detect()['engine']);candidate,_=prepare(base,s)
        result=subprocess.run(['picom','--config',str(candidate),'--diagnostics'],capture_output=True,text=True,timeout=6)
        if result.returncode:raise RuntimeError('Picom rejected the candidate: '+(result.stderr.strip() or result.stdout.strip())[-400:])
        previous=path.read_text() if path.exists() else None
        backup=state/'animation-backups'/datetime.now().strftime('%Y%m%dT%H%M%S-%f')
        backup.mkdir(parents=True,mode=0o700)
        atomic_write(backup/'settings.json',previous or json.dumps(DEFAULTS,indent=2))
        shutil.copy2(base,backup/base.name)
        atomic_write(path,json.dumps(s,indent=2)+'\n')
        try:restart()
        except Exception:
            if previous is None:path.unlink(missing_ok=True)
            else:atomic_write(path,previous)
            restart()
            raise
        return backup


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run');parser.add_argument('--status',action='store_true');parser.add_argument('--compositor-active',action='store_true');args=parser.parse_args()
    if args.compositor_active:return 0 if compositor_active() else 1
    if args.run:
        try:config,env=prepare(Path(args.run));os.execvpe('picom',['picom','--config',str(config)],env)
        except Exception as error:print('Animation settings: '+str(error),file=sys.stderr);return 1
    if args.status:print(json.dumps({'settings':load(),'backend':detect()},indent=2))
    return 0

if __name__=='__main__':raise SystemExit(main())
