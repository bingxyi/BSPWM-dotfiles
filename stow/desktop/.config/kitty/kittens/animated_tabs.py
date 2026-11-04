"""Preserve Kitty actions, adding optional input-transparent X11 transitions."""
import sys
import time
from pathlib import Path
from kittens.tui.handler import result_handler


def main(args):
    return None


@result_handler(no_ui=True)
def handle_result(args,data,target_window_id,boss):
    from kitty.fast_data_types import add_timer
    actions={
        'new':lambda:boss.new_tab_with_cwd(),
        'split':lambda:boss.launch('--location=split','--cwd=current'),
        'next':boss.next_tab,'previous':boss.previous_tab,
        'forward':boss.move_tab_forward,'backward':boss.move_tab_backward,
    }
    name=args[1] if len(args)>1 else 'next'
    if name not in actions:return
    directory=str(Path.home()/'.config/rice/bin')
    if directory not in sys.path:sys.path.insert(0,directory)
    try:
        from kitty.utils import platform_window_id
        from motion_client import request
        manager=boss.active_tab_manager
        xid=platform_window_id(manager.os_window_id) if manager else None
        token=str(time.monotonic_ns())
        prepared=bool(xid) and request('prepare',window=xid,token=token,
                    direction=-1 if name in ('previous','backward') else 1,
                    tabbar=name in ('forward','backward'))
    except (ImportError,OSError,AttributeError):prepared=False
    try:actions[name]()
    finally:
        if prepared:add_timer(lambda _timer:request('commit',token=token),.025,False)
