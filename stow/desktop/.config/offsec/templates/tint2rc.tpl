#---------------------------------------------
# offsec-dotfiles :: perfil Nyx — painel vertical (tint2)
# gerado por theme.sh a partir de templates/tint2rc.tpl — não editar à mão
#---------------------------------------------

#---------------------------------------------
# BACKGROUNDS
#---------------------------------------------
# 1 — painel
rounded = 0
border_width = 0
border_sides = R
border_color = {{surface}} 100
background_color = {{bg_alt}} 92
background_color_hover = {{bg_alt}} 92
background_color_pressed = {{bg_alt}} 92

# 2 — item neutro (sem fundo)
rounded = 10
border_width = 0
background_color = {{bg_alt}} 0
background_color_hover = {{surface}} 70
background_color_pressed = {{surface}} 90

# 3 — janela ativa
rounded = 10
border_width = 0
background_color = {{accent}} 22
border_color = {{accent}} 100
background_color_hover = {{accent}} 32
background_color_pressed = {{accent}} 40

# 4 — janela urgente
rounded = 10
border_width = 1
background_color = {{urgent}} 30
border_color = {{urgent}} 100

# 5 — pílula de status
rounded = 10
border_width = 0
background_color = {{surface}} 55
background_color_hover = {{surface}} 85
background_color_pressed = {{accent}} 60

#---------------------------------------------
# PAINEL
#---------------------------------------------
panel_items = LETFEEEEEEEESC
panel_monitor = primary
panel_position = top left vertical
panel_size = 100% 46
panel_margin = 0 0
panel_padding = 4 8 8
panel_background_id = 1
wm_menu = 1
panel_dock = 0
panel_pivot_struts = 0
panel_layer = bottom
panel_window_name = offsec-nyx
disable_transparency = 0
mouse_effects = 1
font_shadow = 0
mouse_hover_icon_asb = 100 0 12
mouse_pressed_icon_asb = 100 0 0
autohide = 0
autohide_show_timeout = 0.1
autohide_hide_timeout = 1
autohide_height = 2
strut_policy = follow_size
scale_relative_to_dpi = 0

#---------------------------------------------
# LAUNCHER (atalhos fixos do topo)
#---------------------------------------------
launcher_icon_theme = {{gtk_icons}}
launcher_icon_theme_override = 1
launcher_padding = 2 4 8
launcher_background_id = 0
launcher_icon_background_id = 2
launcher_icon_size = 24
launcher_icon_asb = 100 0 0
launcher_tooltip = 1
launcher_item_app = /usr/share/applications/kitty.desktop
launcher_item_app = /usr/share/applications/firefox.desktop
launcher_item_app = /usr/share/applications/thunar.desktop
launcher_item_app = {{home}}/.local/share/applications/offsec-menu.desktop

#---------------------------------------------
# EXECUTOR 1 — coluna de workspaces (glifo por workspace, ativo destacado)
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/ws-tint2.sh
execp_interval = 0
execp_continuous = 10
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 13
execp_font_color = {{fg_dim}} 100
execp_padding = 2 6
execp_background_id = 0
execp_tooltip = Click: workspace selector · scroll to switch
execp_lclick_command = {{home}}/.config/offsec/bin/ws-tint2.sh --menu
execp_rclick_command = bspc desktop -l next
execp_uwheel_command = bspc desktop -f prev.local
execp_dwheel_command = bspc desktop -f next.local

#---------------------------------------------
# TASKBAR (janelas do desktop atual)
#---------------------------------------------
taskbar_mode = single_desktop
taskbar_hide_if_empty = 1
taskbar_padding = 2 4 6
taskbar_background_id = 0
taskbar_active_background_id = 0
taskbar_name = 0
taskbar_distribute_size = 0
taskbar_sort_order = none
task_align = center

task_text = 0
task_icon = 1
task_centered = 1
task_maximum_size = 34 34
task_padding = 4 4 6
task_tooltip = 1
task_thumbnail = 0
task_background_id = 2
task_active_background_id = 3
task_urgent_background_id = 4
task_iconified_background_id = 2
task_icon_asb = 78 0 0
task_active_icon_asb = 100 0 6
task_urgent_icon_asb = 100 0 10

#---------------------------------------------
# EXECUTOR 2 — alvo e proxy do engagement
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --engagement
execp_interval = 3
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 11
execp_font_color = {{fg}} 100
execp_padding = 2 6
execp_background_id = 5
execp_tooltip = Active engagement and target · click to change
execp_lclick_command = {{home}}/.config/offsec/bin/offsec-menu.sh
execp_rclick_command = {{home}}/.config/offsec/bin/target.sh --menu

#---------------------------------------------
# EXECUTOR 3 — VPN e rede
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --network
execp_interval = 5
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 11
execp_font_color = {{fg}} 100
execp_padding = 2 6
execp_background_id = 5
execp_tooltip = Network and tun0 · click for VPN menu
execp_lclick_command = {{home}}/.config/offsec/bin/vpn.sh --menu
execp_rclick_command = {{home}}/.config/offsec/bin/network.sh --menu

#---------------------------------------------
# EXECUTOR 4 — CPU, memória e temperatura
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --system
execp_interval = 4
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 11
execp_font_color = {{fg_dim}} 100
execp_padding = 2 6
execp_background_id = 0
execp_tooltip = CPU · memory · temperature
execp_lclick_command = kitty -e btop

#---------------------------------------------
# EXECUTOR 5 — volume
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --volume
execp_interval = 2
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 12
execp_font_color = {{fg}} 100
execp_padding = 2 6
execp_background_id = 2
execp_tooltip = Volume · click to mute, scroll to adjust
execp_lclick_command = {{home}}/.config/offsec/bin/volume.sh --toggle
execp_rclick_command = pavucontrol
execp_uwheel_command = {{home}}/.config/offsec/bin/volume.sh --up
execp_dwheel_command = {{home}}/.config/offsec/bin/volume.sh --down

#---------------------------------------------
# EXECUTOR 6 — notificações
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --notifications
execp_interval = 3
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 12
execp_font_color = {{fg}} 100
execp_padding = 2 6
execp_background_id = 2
execp_tooltip = Notification center · Right click toggles Do not disturb
execp_lclick_command = {{home}}/.config/offsec/bin/notifications.sh --list
execp_rclick_command = {{home}}/.config/offsec/bin/notifications.sh --dnd

#---------------------------------------------
# EXECUTOR 7 — bateria (não aparece em desktop: saída vazia)
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/status.sh --battery
execp_interval = 20
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 11
execp_font_color = {{fg_dim}} 100
execp_padding = 2 6
execp_background_id = 0
execp_tooltip = Battery · click for power options
execp_lclick_command = {{home}}/.config/offsec/bin/powermenu.sh

#---------------------------------------------
# EXECUTOR 8 - central de controle (wifi, energia, cafeina, notificacoes)
#---------------------------------------------
execp = new
execp_command = {{home}}/.config/offsec/bin/control.sh --glyph
execp_interval = 4
execp_continuous = 0
execp_has_icon = 0
execp_markup = 1
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 13
execp_font_color = #9c93b0 100
execp_padding = 2 6
execp_background_id = 2
execp_tooltip = Control center (Super+Shift+N / Super+C) - Right click: keep awake
execp_lclick_command = {{home}}/.config/offsec/bin/control.sh --toggle
execp_rclick_command = {{home}}/.config/offsec/bin/caffeine.sh --toggle
execp_uwheel_command = {{home}}/.config/offsec/bin/volume.sh --up
execp_dwheel_command = {{home}}/.config/offsec/bin/volume.sh --down

#---------------------------------------------
# EXECUTOR 9 — multimídia
execp = new
execp_command = {{home}}/.config/offsec/bin/media.sh --glyph
execp_interval = 0
execp_continuous = 0
execp_has_icon = 0
execp_markup = 0
execp_centered = 1
execp_font = JetBrainsMono Nerd Font 14
execp_font_color = {{accent}} 100
execp_padding = 2 6
execp_background_id = 2
execp_tooltip = Media (Super+Ctrl+M) · artwork, playback, progress and volume
execp_lclick_command = {{home}}/.config/offsec/bin/media.sh --toggle

# SYSTRAY
#---------------------------------------------
systray_padding = 2 4 6
systray_background_id = 0
systray_sort = ascending
systray_icon_size = 18
systray_icon_asb = 100 0 0
systray_monitor = primary
systray_name_filter =

#---------------------------------------------
# RELÓGIO (empilhado: hora em cima, minuto embaixo)
#---------------------------------------------
time1_format = %H
time1_font = JetBrainsMono Nerd Font Bold 12
time2_format = %M
time2_font = JetBrainsMono Nerd Font 11
time1_timezone =
time2_timezone =
clock_font_color = {{accent}} 100
clock_padding = 2 6
clock_background_id = 0
clock_tooltip = %A, %B %d, %Y
clock_tooltip_timezone =
clock_lclick_command = {{home}}/.config/offsec/bin/powermenu.sh
clock_rclick_command = {{home}}/.config/offsec/bin/theme.sh --menu
clock_uwheel_command =
clock_dwheel_command =

#---------------------------------------------
# TOOLTIP
#---------------------------------------------
tooltip_show_timeout = 0.4
tooltip_hide_timeout = 0.1
tooltip_padding = 8 6
tooltip_background_id = 5
tooltip_font_color = {{fg}} 100
tooltip_font = JetBrainsMono Nerd Font 10
