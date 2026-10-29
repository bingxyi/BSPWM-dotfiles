#!/usr/bin/env bash
# rice :: notification history as JSON for Eww
# Read the file written by notif-log.sh, which is called by Dunst.

LOG="${XDG_DATA_HOME:-$HOME/.local/share}/rice/notifications.json"

if ! command -v jq &>/dev/null; then
    echo '[]'
    exit 0
fi

if [ ! -s "$LOG" ]; then
    echo '[]'
    exit 0
fi

jq -s -c 'reverse | .[0:40]' "$LOG" 2>/dev/null || echo '[]'
