# gerado por theme.sh — não editar à mão (edite templates/starship.toml.tpl)
add_newline = true
command_timeout = 800

format = """
[](fg:{{surface}})\
$os\
$directory\
$git_branch$git_status\
$python$golang$nodejs$rust$java\
[](fg:{{surface}})\
$fill\
${custom.target}${custom.vpn}${custom.engagement}\
$cmd_duration\
$line_break\
$character"""

[fill]
symbol = " "

[os]
disabled = false
style = "bg:{{surface}} fg:{{accent}}"
format = "[ $symbol ]($style)"

[os.symbols]
Arch = "󰣇"
Linux = "󰌽"

[directory]
style = "bg:{{surface}} fg:{{fg}}"
format = "[ $path ]($style)"
truncation_length = 4
truncation_symbol = "…/"
read_only = " 󰌾"

[directory.substitutions]
"Documents" = "󰈙"
"Downloads" = "󰇚"
"Pictures" = "󰋩"
"engagements" = "󰯄"

[git_branch]
symbol = ""
style = "bg:{{surface}} fg:{{green}}"
format = "[ $symbol $branch ]($style)"

[git_status]
style = "bg:{{surface}} fg:{{yellow}}"
format = "[$all_status$ahead_behind ]($style)"

[python]
symbol = "󰌠"
style = "bg:{{surface}} fg:{{yellow}}"
format = "[ $symbol ($virtualenv) ]($style)"

[golang]
symbol = "󰟓"
style = "bg:{{surface}} fg:{{cyan}}"
format = "[ $symbol ]($style)"

[nodejs]
symbol = "󰎙"
style = "bg:{{surface}} fg:{{green}}"
format = "[ $symbol ]($style)"

[rust]
symbol = "󱘗"
style = "bg:{{surface}} fg:{{orange}}"
format = "[ $symbol ]($style)"

[java]
symbol = "󰬷"
style = "bg:{{surface}} fg:{{red}}"
format = "[ $symbol ]($style)"

[cmd_duration]
min_time = 2000
style = "fg:{{muted}}"
format = "[ 󱎫 $duration]($style)"

[character]
success_symbol = "[❯](bold {{accent}})"
error_symbol = "[❯](bold {{urgent}})"
vimcmd_symbol = "[❮](bold {{green}})"

[custom.target]
description = "Target set por target.sh"
command = 'cat "$HOME/.local/share/offsec/target"'
when = 'test -s "$HOME/.local/share/offsec/target"'
shell = ["bash", "--noprofile", "--norc"]
style = "fg:{{red}}"
format = "[  $output ]($style)"

[custom.vpn]
description = "tun0 IP while the lab VPN is connected"
command = 'ip -4 -o addr show tun0 2>/dev/null | awk "{print \$4}" | cut -d/ -f1'
when = 'ip link show tun0 >/dev/null 2>&1'
shell = ["bash", "--noprofile", "--norc"]
style = "fg:{{green}}"
format = "[ 󰖂 $output ]($style)"

[custom.engagement]
description = "Active engagement"
command = 'basename "$(cat "$HOME/.local/share/offsec/engagement")"'
when = 'test -s "$HOME/.local/share/offsec/engagement"'
shell = ["bash", "--noprofile", "--norc"]
style = "fg:{{magenta}}"
format = "[ 󰯄 $output ]($style)"
