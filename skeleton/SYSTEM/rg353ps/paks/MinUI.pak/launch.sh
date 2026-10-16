#!/bin/sh
# NextUI main loop on BaseOS/RG353PS. BaseOS owns the kernel, mounts and boot UI.
set -u

export PLATFORM=rg353ps
export DEVICE=rg353ps
export IS_NEXT=yes
export SDCARD_PATH=/mnt/SDCARD
export ROMS_PATH="$SDCARD_PATH/Roms"
export BIOS_PATH="$SDCARD_PATH/Bios"
export SAVES_PATH="$SDCARD_PATH/Saves"
export STATES_PATH="$SDCARD_PATH/States"
export CHEATS_PATH="$SDCARD_PATH/Cheats"
export SYSTEM_PATH="$SDCARD_PATH/.system/$PLATFORM"
export CORES_PATH="$SYSTEM_PATH/cores"
export USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
export SHARED_USERDATA_PATH="$SDCARD_PATH/.userdata/shared"
export LOGS_PATH="$USERDATA_PATH/logs"
export HOOKS_PATH="$USERDATA_PATH/.hooks"
export HOME="$USERDATA_PATH"
export PATH="$SYSTEM_PATH/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
LD_LIBRARY_PATH=""
export LD_LIBRARY_PATH="$SYSTEM_PATH/lib:/usr/lib:/lib"

mkdir -p "$ROMS_PATH" "$BIOS_PATH" "$SAVES_PATH" "$STATES_PATH" \
    "$CHEATS_PATH" "$USERDATA_PATH" "$LOGS_PATH" "$HOOKS_PATH" \
    "$SHARED_USERDATA_PATH/.minui"

LAUNCH_LOG="$LOGS_PATH/launch.txt"
printf 'launch: RG353PS NextUI starting %s\n' "$(date)" > "$LAUNCH_LOG"

if [ -f /tmp/poweroff ]; then
    rm -f /tmp/poweroff
    /sbin/poweroff
    exit 0
fi
if [ -f /tmp/reboot ]; then
    rm -f /tmp/reboot
    /sbin/reboot
    exit 0
fi

sh "$SYSTEM_PATH/bin/governor.sh" auto >/dev/null 2>&1 || :
"$SYSTEM_PATH/bin/run_hooks.sh" boot.d >/dev/null 2>&1 || :

EXEC_PATH=/tmp/nextui_exec
NEXT_PATH=/tmp/next
touch "$EXEC_PATH"

while [ -f "$EXEC_PATH" ]; do
    printf 'launch: starting nextui.elf %s\n' "$(date)" >> "$LAUNCH_LOG"
    "$SYSTEM_PATH/bin/nextui.elf" >> "$LOGS_PATH/nextui.txt" 2>&1
    rc=$?
    printf 'launch: nextui.elf exited %s at %s\n' "$rc" "$(date)" >> "$LAUNCH_LOG"

    if [ -f /tmp/poweroff ]; then
        rm -f /tmp/poweroff
        /sbin/poweroff
        exit 0
    fi
    if [ -f /tmp/reboot ]; then
        rm -f /tmp/reboot
        /sbin/reboot
        exit 0
    fi

    if [ -f "$NEXT_PATH" ]; then
        CMD=$(cat "$NEXT_PATH")
        "$SYSTEM_PATH/bin/run_hooks.sh" pre-launch.d >/dev/null 2>&1 || :
        # NextUI writes the selected pak/ROM command to this transient file.
        eval "$CMD"
        "$SYSTEM_PATH/bin/run_hooks.sh" post-launch.d >/dev/null 2>&1 || :
        rm -f "$NEXT_PATH"
        sh "$SYSTEM_PATH/bin/governor.sh" performance >/dev/null 2>&1 || :
    fi
done

/sbin/poweroff
