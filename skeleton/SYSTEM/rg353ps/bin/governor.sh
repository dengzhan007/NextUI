#!/bin/sh
set -u
MODE=auto
if [ "$#" -gt 0 ]; then MODE="$1"; fi

choose_governor() {
    wanted="$1"
    available="$2"
    for candidate in $available; do
        [ "$candidate" = "$wanted" ] && { printf '%s' "$wanted"; return 0; }
    done
    for fallback in schedutil ondemand performance powersave; do
        for candidate in $available; do
            [ "$candidate" = "$fallback" ] && { printf '%s' "$fallback"; return 0; }
        done
    done
    printf ''
}

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$policy" ] || continue
    [ -w "$policy/scaling_governor" ] || continue
    available=$(cat "$policy/scaling_available_governors" 2>/dev/null || :)
    case "$MODE" in
        performance) wanted=performance ;;
        powersave) wanted=powersave ;;
        *) wanted=schedutil ;;
    esac
    governor=$(choose_governor "$wanted" "$available")
    [ -n "$governor" ] && echo "$governor" > "$policy/scaling_governor" 2>/dev/null || :
    [ ! -r "$policy/cpuinfo_max_freq" ] || cat "$policy/cpuinfo_max_freq" > "$policy/scaling_max_freq" 2>/dev/null || :
done

for devfreq in /sys/class/devfreq/*gpu* /sys/class/devfreq/*mali*; do
    [ -d "$devfreq" ] || continue
    [ -w "$devfreq/governor" ] || continue
    available=$(cat "$devfreq/available_governors" 2>/dev/null || :)
    governor=$(choose_governor simple_ondemand "$available")
    [ -n "$governor" ] && echo "$governor" > "$devfreq/governor" 2>/dev/null || :
done
exit 0
