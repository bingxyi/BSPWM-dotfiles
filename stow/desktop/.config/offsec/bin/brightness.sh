#!/usr/bin/env bash
# Purpose: brightnessctl with OSD; a no-op on desktops without a backlight
# Usage: brightness.sh --up | --down | --get

if ! command -v brightnessctl &>/dev/null; then
    echo "0"
    exit 0
fi

if [ -z "$(brightnessctl -l 2>/dev/null | grep -i backlight)" ]; then
    # No backlight: do nothing and succeed.
    echo "0"
    exit 0
fi

case "${1:---get}" in
-u | --up) brightnessctl set 5%+ >/dev/null ;;
-d | --down) brightnessctl set 5%- >/dev/null ;;
-g | --get) ;;
*)
    echo "usage: $(basename "$0") --up|--down|--get" >&2
    exit 1
    ;;
esac

VALUE=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
echo "${VALUE:-0}"

if [ "${1:-}" != "--get" ] && [ "${1:-}" != "-g" ]; then
    notify-send -a archlinux -u low -i display-brightness \
        -h "int:value:${VALUE:-0}" -h string:x-dunst-stack-tag:osd \
        "Brightness" "${VALUE:-0}%"
fi
exit 0
