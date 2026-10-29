#!/usr/bin/env bash
# Shared atomic history writer; the local receipt monitor adds DND deadlines.
exec /usr/bin/python3 "$HOME/.config/rice/bin/notification-retention.py"
