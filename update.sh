#!/bin/sh
set -eu
repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec python3 -B "$repo_dir/scripts/update.py" "$@"
