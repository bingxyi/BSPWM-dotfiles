#!/usr/bin/env bash
# BSPWM-dotfiles :: power profile (always readable; writable with a helper)
#
# Backend preference:
#   1. powerprofilesctl (power-profiles-daemon), authorized through polkit
#   2. /usr/local/bin/offsec-powerprofile through sudo -n, with fixed arguments
#   3. read-only mode with instructions for installing the missing backend
#
# Reading never requires privileges: the bar always shows the current state.

SCRIPT_NAME=${0##*/}

# shellcheck source=/dev/null
. "$HOME/.config/offsec/bin/lib.sh"

CPUFREQ="/sys/devices/system/cpu/cpu0/cpufreq"
HELPER="/usr/local/bin/offsec-powerprofile"

function usage() {
    cat <<EOM

CPU power profiles.
usage: ${SCRIPT_NAME} [options]
    --get            Current profile (performance|balanced|power)
    --icon           Profile icon
    --label          Profile name
    --set <profile>  Set the profile
    --cycle          Select the next profile
    --menu           Open profile selector
    --available      Print 1 if writable, otherwise 0
    --gpu            NVIDIA PowerMizer status
    --restore        Restore the saved profile
    --help           Show this help

EOM
    exit 1
}

function current_profile() {
    if command -v powerprofilesctl >/dev/null 2>&1; then
        case "$(powerprofilesctl get 2>/dev/null)" in
        performance) printf 'performance'; return 0 ;;
        power-saver) printf 'power'; return 0 ;;
        balanced) printf 'balanced'; return 0 ;;
        esac
    fi

    local gov epp
    gov=$(cat "$CPUFREQ/scaling_governor" 2>/dev/null)
    epp=$(cat "$CPUFREQ/energy_performance_preference" 2>/dev/null)

    if [ "$gov" = "performance" ] || [ "$epp" = "performance" ]; then
        printf 'performance'
    elif [ "$epp" = "power" ]; then
        printf 'power'
    else
        printf 'balanced'
    fi
}

function can_write() {
    command -v powerprofilesctl >/dev/null 2>&1 && return 0
    [ -x "$HELPER" ] && return 0
    [ -w "$CPUFREQ/scaling_governor" ] && return 0
    return 1
}

function set_profile() {
    local p="$1"
    case "$p" in
    performance | balanced | power) ;;
    *)
        echo "Error: invalid profile '$p' (performance|balanced|power)" >&2
        return 1
        ;;
    esac

    if command -v powerprofilesctl >/dev/null 2>&1; then
        local ppd="$p"
        [ "$p" = "power" ] && ppd="power-saver"
        powerprofilesctl set "$ppd" 2>/dev/null && { announce "$p"; return 0; }
    fi

    if [ -x "$HELPER" ]; then
        if sudo -n "$HELPER" "$p" 2>/dev/null; then
            announce "$p"
            return 0
        fi
    fi

    notify "Power profile" \
        "Read only — install the helper (see ~/.config/offsec/system/)" \
        dialog-warning normal
    return 1
}

# ---------------------------------------------------------------------------
# NVIDIA GPU: the power profile also controls PowerMizer.
#   performance -> 1 (prefer maximum performance)
#   other       -> 0 (adaptive, the driver default)
#
# Some drivers accept writes but silently discard them: nvidia-settings
# reports "assigned value 1", yet the next read returns 0.
# This usually means Xorg lacks Coolbits; see
# ~/.config/offsec/system/install-performance.sh. Read the value back
# instead of relying on the exit status.
# ---------------------------------------------------------------------------
function gpu_powermizer() {
    command -v nvidia-settings >/dev/null 2>&1 || return 0
    [ -n "${DISPLAY:-}" ] || return 0

    local want=0
    [ "$1" = "performance" ] && want=1

    nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=$want" >/dev/null 2>&1 || return 0

    local got
    got=$(nvidia-settings -q '[gpu:0]/GPUPowerMizerMode' 2>/dev/null |
        grep -oP '\]\): \K[0-9]+' | head -n1)
    if [ -n "$got" ] && [ "$got" != "$want" ]; then
        state_set gpu_powermizer_blocked 1
        return 0
    fi
    state_clear gpu_powermizer_blocked
    state_set gpu_powermizer "$want"
}

# 1 when the driver rejected the last PowerMizer write.
function gpu_blocked() { [ "$(state_get gpu_powermizer_blocked 0)" = 1 ]; }

function announce() {
    state_set power_profile "$1"
    gpu_powermizer "$1"
    notify "Power profile" "$(label_for "$1")" "$(icon_name_for "$1")" low
    # tint2 does not handle RTMIN+3; that signal terminates the bar.
    # Executors already refresh status at the intervals configured in tint2rc.
    eww_refresh
}

function eww_refresh() {
    command -v eww >/dev/null 2>&1 || return 0
    eww -c "$HOME/.config/eww" update \
        power_profile="$(current_profile)" 2>/dev/null || true
}

function icon_for() {
    case "$1" in
    performance) printf '󰓅' ;;
    power) printf '󰌪' ;;
    *) printf '󰾅' ;;
    esac
}

function label_for() {
    case "$1" in
    performance) printf 'Performance' ;;
    power) printf 'Power saver' ;;
    *) printf 'Balanced' ;;
    esac
}

function icon_name_for() {
    case "$1" in
    performance) printf 'power-profile-performance-symbolic' ;;
    power) printf 'power-profile-power-saver-symbolic' ;;
    *) printf 'power-profile-balanced-symbolic' ;;
    esac
}

function cycle_profile() {
    case "$(current_profile)" in
    balanced) set_profile performance ;;
    performance) set_profile power ;;
    *) set_profile balanced ;;
    esac
}

function menu_profile() {
    exit_on_missing_tools rofi
    local cur chosen
    cur=$(current_profile)
    chosen=$(
        printf '󰾅  Balanced\n󰓅  Performance\n󰌪  Power saver\n' |
            rofi -dmenu -i -p "Power (current: $(label_for "$cur"))" \
                -theme "$ROFI_MENU_THEME" -lines 3
    )
    [ -z "$chosen" ] && exit 0
    case "$chosen" in
    *Performance) set_profile performance ;;
    *"Power saver") set_profile power ;;
    *Balanced) set_profile balanced ;;
    esac
}

function main() {
    local action="get" value=""

    while (($#)); do
        case $1 in
        -g | --get) action="get" ;;
        -i | --icon) action="icon" ;;
        -l | --label) action="label" ;;
        -s | --set)
            shift
            value="$1"
            action="set"
            ;;
        -c | --cycle) action="cycle" ;;
        -m | --menu) action="menu" ;;
        --restore) action="restore" ;;
        --available) action="available" ;;
        --gpu) action="gpu" ;;
        -h | --help) usage ;;
        *)
            echo "Error: unknown option '$1'" >&2
            usage
            ;;
        esac
        shift
    done

    case "$action" in
    restore)
        local saved
        saved=$(state_get power_profile '')
        [ -z "$saved" ] || set_profile "$saved"
        ;;
    get) current_profile ;;
    icon) icon_for "$(current_profile)" ;;
    label) label_for "$(current_profile)" ;;
    set) set_profile "$value" ;;
    cycle) cycle_profile ;;
    menu) menu_profile ;;
    available) can_write && printf '1' || printf '0' ;;
    gpu)
        if ! command -v nvidia-settings >/dev/null 2>&1; then
            printf 'No nvidia-settings\n'
        elif gpu_blocked; then
            printf 'Rejected by the driver (Coolbits missing in Xorg)\n'
        else
            printf 'PowerMizer=%s\n' "$(state_get gpu_powermizer 'unknown')"
        fi
        ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
