#!/usr/bin/env bash
# Restaura somente preferências escolhidas pelo usuário.
. "$HOME/.config/offsec/bin/lib.sh"
exec 9>"${XDG_RUNTIME_DIR:-$STATE_DIR}/offsec-session-restore.lock"
flock 9
"$OFFSEC_DIR/bin/caffeine.sh" --restore 9>&-
# Dunst pode ainda estar registrando o serviço DBus no primeiro login.
for ((attempt=0; attempt<30; attempt++)); do
    if dunstctl is-paused >/dev/null 2>&1; then
        "$OFFSEC_DIR/bin/notifications.sh" --restore 9>&-
        break
    fi
    sleep 0.2
done
"$OFFSEC_DIR/bin/powerprofile.sh" --restore 9>&-
