#!/bin/sh
[ -d /etc/X11/xinit/xinitrc.d ] && for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
    [ -x "$f" ] && . "$f"
done

# Use the same environment source as SDDM so both startup paths agree.
[ -f "$HOME/.xprofile" ] && . "$HOME/.xprofile"

exec bspwm
