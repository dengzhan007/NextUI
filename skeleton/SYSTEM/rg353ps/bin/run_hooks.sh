#!/bin/sh
DIR_NAME=""
SYNC_ONLY=""
[ "$#" -lt 1 ] || DIR_NAME="$1"
[ "$#" -lt 2 ] || SYNC_ONLY="$2"
SDCARD_PATH=/mnt/SDCARD
PLATFORM=rg353ps
USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
HOOK_DIR="$USERDATA_PATH/.hooks/$DIR_NAME"
[ -d "$HOOK_DIR" ] || exit 0
case "$DIR_NAME" in
    pre-*) export HOOK_PHASE=pre ;;
    post-*) export HOOK_PHASE=post ;;
    boot*) export HOOK_PHASE=boot ;;
esac
export HOOK_CATEGORY="$DIR_NAME"
for script in "$HOOK_DIR"/*.sh; do
    [ -f "$script" ] || continue
    if [ "$SYNC_ONLY" = "--sync-only" ] || echo "$script" | grep -q '\.sync\.sh$'; then
        ( "$script" ) >/dev/null 2>&1 || :
    else
        ( "$script" ) >/dev/null 2>&1 &
    fi
done
wait
