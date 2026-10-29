#!/usr/bin/env bash
# Shared atomic history writer; the local receipt monitor adds DND deadlines.
exec /usr/bin/python3 "$HOME/.config/offsec/bin/notification-retention.py"
