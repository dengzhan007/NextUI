#!/bin/sh
set -u

export PLATFORM=rg353ps
export DEVICE=rg353ps
# BaseOS has no X11/Wayland server; use the verified full-screen DRM path.
export SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-kmsdrm}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-alsa}"
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

# The mainline RG353PS sound-card order is HDMI=0, RK817 speaker/headphones=1.
# Detect the codec card rather than assuming the default ALSA card is audible.
USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
mkdir -p "$USERDATA_PATH" 2>/dev/null || :
AUDIO_CARD=$(awk '/rk817ext|rk817_ext/ { print $1; exit }' /proc/asound/cards 2>/dev/null || :)
case "$AUDIO_CARD" in ''|*[!0-9]*) AUDIO_CARD= ;; esac
if [ -n "$AUDIO_CARD" ]; then
    export BASEOS_AUDIO_CARD="$AUDIO_CARD"
    ASOUND_CONFIG="$USERDATA_PATH/.asoundrc"
    if [ ! -e "$ASOUND_CONFIG" ] || grep -q 'baseos-rg353ps-nextui auto route' "$ASOUND_CONFIG" 2>/dev/null; then
        cat > "$ASOUND_CONFIG" <<EOF
# baseos-rg353ps-nextui auto route
pcm.!default {
    type plug
    slave.pcm {
        type hw
        card $AUDIO_CARD
        device 0
    }
}
ctl.!default {
    type hw
    card $AUDIO_CARD
}
EOF
    fi
else
    echo "NextUI: RK817 audio card not detected; keeping ALSA's current default" > /dev/kmsg 2>/dev/null || :
fi

exec sh "$SYSTEM_PATH/paks/MinUI.pak/launch.sh"
