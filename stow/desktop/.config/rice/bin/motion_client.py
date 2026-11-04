"""Small optional client for the event-driven X11 transition service."""
import json
import os
from pathlib import Path
import socket


def socket_path():
    return Path(os.environ.get('XDG_RUNTIME_DIR') or f'/run/user/{os.getuid()}')/'rice-motion.sock'


def request(operation, **values):
    """Failure leaves the original WM/terminal action available to the caller."""
    try:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(.18)
            connection.connect(str(socket_path()))
            connection.sendall(json.dumps({'op':operation,**values}).encode()+b'\n')
            return connection.recv(64).strip()==b'ok'
    except (OSError,ValueError):
        return False
