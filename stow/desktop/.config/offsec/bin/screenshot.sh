#!/usr/bin/env bash
# BSPWM-dotfiles :: save screenshots directly to the engagement evidence directory

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

RECORD_PID_FILE="$STATE_DIR/recording.pid"

function usage() {
    cat <<EOM

Capture screenshots or record the screen.
usage: ${SCRIPT_NAME} [--menu|--area|--full|--window|--record|--help]
Saved to the active engagement evidence directory or Pictures/screenshots.

EOM
    exit 1
}

function engagement_dir_preview() {
    "$OFFSEC_DIR/bin/engagement.sh" --evidence 2>/dev/null
}

function main() {
    local action="area"

    while (($#)); do
        case $1 in
        -a | --area | --region) action="area" ;;
        -f | --full) action="full" ;;
        -w | --window) action="window" ;;
        -r | --record) action="record" ;;
        -m | --menu) action="menu" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    area) shot_area ;;
    full) shot_full ;;
    window) shot_window ;;
    record) toggle_record ;;
    menu) menu_shot ;;
    esac
}

function target_dir() {
    local dir
    dir=$("$OFFSEC_DIR/bin/engagement.sh" --evidence)
    mkdir -p -- "$dir" || return 1
    printf '%s' "$dir"
}

function filename() {
    local dir
    dir=$(target_dir) || return 1
    printf '%s/%s.png' "$dir" "$(date '+%Y%m%d-%H%M%S-%N')"
}

function menu_shot() {
    local choice
    choice=$(printf '󰆞  area\n󰹑  Full screen\n󰖯  Active window\n󰑊  Record screen\n󰉏  Open evidence\n' |
        rofi -dmenu -i -p "screenshot" -theme "$ROFI_MENU_THEME" -lines 5)
    case "$choice" in
    *area*) shot_area ;;
    *"Full screen"*) shot_full ;;
    *"Active window"*) shot_window ;;
    *"Record screen"*) toggle_record ;;
    *evidence*) thunar "$(target_dir)" & ;;
    esac
}

function shot_area() {
    # One interactive capture at a time; repeated Print presses do not open more dialogs.
    exec 8>"${XDG_RUNTIME_DIR:-$STATE_DIR}/offsec-screenshot.lock"
    flock -n 8 || return 0
    local file result
    file=$(filename) || return 1

    if command -v flameshot &>/dev/null; then
        ensure_flameshot || return 1
        # Flameshot provides report annotations: arrows, blur, and highlights.
        # It saves and copies after confirmation, keeping crop, arrow, text,
        # and drawing tools available until Enter is pressed.
        # Do not pass the lock to the persistent daemon.
        flameshot gui --path "$file" --clipboard 8>&- \
            >>"$STATE_DIR/screenshot.log" 2>&1
        result=$?
        if [ "$result" -eq 2 ]; then
            return 0
        fi
        if [ "$result" -ne 0 ]; then
            rm -f "$file"
            notify "screenshot" "Could not capture; see screenshot.log" dialog-error critical
            return 1
        fi
        return 0
    else
        exit_on_missing_tools maim slop
        if ! maim -u -s -b 2 -c 0.6,0.4,0.9,0.4 "$file"; then
            rm -f "$file"
            exit 0
        fi
    fi
    finish "$file"
}

function flameshot_ready() {
    gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner org.flameshot.Flameshot \
        2>/dev/null | grep -q true
}

function ensure_flameshot() {
    exit_on_missing_tools gdbus
    flameshot_ready && return 0
    # Start the server before the editor without passing the capture lock.
    flameshot >>"$STATE_DIR/screenshot.log" 2>&1 8>&- &
    local attempt
    for ((attempt=0; attempt<40; attempt++)); do
        flameshot_ready && return 0
        sleep 0.025
    done
    notify "screenshot" "Flameshot failed to start; see screenshot.log" dialog-error critical
    return 1
}

function shot_full() {
    local file
    file=$(filename) || return 1
    exit_on_missing_tools maim
    maim -u "$file" || exit 1
    finish "$file"
}

function shot_window() {
    local file
    file=$(filename) || return 1
    exit_on_missing_tools maim xdotool
    maim -u -i "$(xdotool getactivewindow)" "$file" || exit 1
    finish "$file"
}

function finish() {
    local file="$1"
    xclip -selection clipboard -t image/png -i "$file" 2>/dev/null 8>&-
    notify "Screenshot saved" "$(basename "$file")" "$file" low
}

function toggle_record() {
    if [ -f "$RECORD_PID_FILE" ]; then
        local pid
        pid=$(cat "$RECORD_PID_FILE")
        kill -INT "$pid" 2>/dev/null
        rm -f "$RECORD_PID_FILE"
        notify "recording" "finished" media-record
        return 0
    fi

    exit_on_missing_tools ffmpeg
    local file geometry
    file="$(target_dir)/$(date '+%Y%m%d-%H%M%S').mp4"
    geometry=$(xdpyinfo | awk '/dimensions:/ {print $2; exit}')

    ffmpeg -y -f x11grab -framerate 30 -video_size "$geometry" -i "$DISPLAY" \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p "$file" \
        >"$STATE_DIR/ffmpeg.log" 2>&1 &
    echo $! >"$RECORD_PID_FILE"
    notify "recording" "Started — Super+Print to stop" media-record
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
