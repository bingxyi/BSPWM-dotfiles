#!/usr/bin/env bash
# rice :: portable monitor layout. Private preferences stay outside Git.
set -eu
if [[ -r "$HOME/.config/bspwm/monitors.local.sh" ]]; then
    set -a
    # shellcheck source=/dev/null
    . "$HOME/.config/bspwm/monitors.local.sh"
    set +a
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "$script_dir/../rice/bin/monitor-layout.py" "$@"
