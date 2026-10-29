#!/bin/sh
[ -d /etc/X11/xinit/xinitrc.d ] && for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
    [ -x "$f" ] && . "$f"
done

# Mesma fonte de ambiente que o SDDM usa — zero divergência entre as rotas
[ -f "$HOME/.xprofile" ] && . "$HOME/.xprofile"

exec bspwm
