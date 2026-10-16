#!/bin/sh
set -u

export PLATFORM=rg353ps
export DEVICE=rg353ps
export SDCARD_PATH=/mnt/SDCARD
SYSTEM_PATH="$SDCARD_PATH/.system/rg353ps"
export SYSTEM_PATH

if ! grep -q " /mnt/SDCARD " /proc/mounts; then
    echo "NextUI: BaseOS user-data partition is not mounted" > /dev/kmsg 2>/dev/null || :
    exit 1
fi
if [ ! -x "$SYSTEM_PATH/paks/MinUI.pak/launch.sh" ] \
    || [ ! -x "$SYSTEM_PATH/bin/nextui.elf" ]; then
    echo "NextUI: install bundle missing under $SYSTEM_PATH" > /dev/kmsg 2>/dev/null || :
    exit 1
fi

exec sh "$SYSTEM_PATH/paks/MinUI.pak/launch.sh"
