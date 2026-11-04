#!/usr/bin/env bash
# Keep a single state reader warm; it sleeps on bspwm events.
exec "$HOME/.config/rice/bin/workspace_state.py" --watch
