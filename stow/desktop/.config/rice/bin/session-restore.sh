#!/usr/bin/env bash
# Restore only preferences explicitly selected by the user.
. "$HOME/.config/rice/bin/lib.sh"
exec 9>"${XDG_RUNTIME_DIR:-$STATE_DIR}/rice-session-restore.lock"
flock 9
"$RICE_DIR/bin/caffeine.sh" --restore 9>&-
# Dunst may still be registering its DBus service on first login.
for ((attempt=0; attempt<30; attempt++)); do
    if dunstctl is-paused >/dev/null 2>&1; then
        "$RICE_DIR/bin/notifications.sh" --restore 9>&-
        break
    fi
    sleep 0.2
done
"$RICE_DIR/bin/powerprofile.sh" --restore 9>&-
