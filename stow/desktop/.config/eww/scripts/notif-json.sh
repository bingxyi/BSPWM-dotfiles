#!/usr/bin/env bash
# offsec-dotfiles :: histórico de notificações em JSON para o eww
# Lê o arquivo alimentado pelo notif-log.sh (chamado pelo dunst).

LOG="${XDG_DATA_HOME:-$HOME/.local/share}/offsec/notifications.json"

if ! command -v jq &>/dev/null; then
    echo '[]'
    exit 0
fi

if [ ! -s "$LOG" ]; then
    echo '[]'
    exit 0
fi

jq -s -c 'reverse | .[0:40]' "$LOG" 2>/dev/null || echo '[]'
