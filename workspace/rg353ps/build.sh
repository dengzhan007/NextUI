#!/bin/sh
set -eu

HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$HERE/../.." && pwd)"

if [ "$#" -eq 0 ] || [ "$1" != "--inside" ]; then
    command -v docker >/dev/null 2>&1 || {
        echo "build.sh: Docker is required" >&2
        exit 1
    }
    exec docker run --rm --platform linux/arm64 \
        -v "$REPO_ROOT:/src" -w /src alpine:3.22 \
        sh /src/workspace/rg353ps/build.sh --inside
fi

apk add --no-cache build-base make git pkgconf zip cmake openssl-dev \
    sdl2-dev sdl2_image-dev sdl2_ttf-dev mesa-dev freetype-dev \
    libsamplerate-dev libzip-dev lz4-dev alsa-lib-dev zlib-dev bzip2-dev xz-dev zstd-dev

PREFIX_LOCAL="$REPO_ROOT/workspace/rg353ps/build/prefix"
BUILD_OUT="$REPO_ROOT/workspace/rg353ps/build"
BUNDLE="$BUILD_OUT/baseos-rg353ps-nextui"
mkdir -p "$PREFIX_LOCAL/include" "$PREFIX_LOCAL/lib"
[ -f "$REPO_ROOT/workspace/hash.txt" ] || echo rg353ps > "$REPO_ROOT/workspace/hash.txt"

make -C "$REPO_ROOT/workspace/rg353ps/libmsettings" \
    CROSS_COMPILE=/usr/bin/ PREFIX_LOCAL="$PREFIX_LOCAL" PREFIX=/usr
for core in fceumm snes9x picodrive pcsx_rearmed; do
    echo "== Building libretro core: $core =="
    if make -C "$REPO_ROOT/workspace/rg353ps/cores" \
        PLATFORM=rg353ps CORE_BUILD_PLATFORM=unix CROSS_COMPILE=/usr/bin/ \
        PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL" "$core"; then
        echo "Core built: $core"
    else
        echo "WARNING: core '$core' did not build; its system pak will be omitted."
    fi
done
make -C "$REPO_ROOT/workspace/all/nextui" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/minarch" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/bootlogo" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/.system/res" \
    "$BUNDLE/.system/rg353ps/bin" "$BUNDLE/.system/rg353ps/lib" \
    "$BUNDLE/.system/rg353ps/cores" "$BUNDLE/.system/rg353ps/shaders" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak" "$BUNDLE/.system/rg353ps/paks/Emus" \
    "$BUNDLE/.baseos/frontends/nextui" "$BUNDLE/Tools/rg353ps/Bootlogo.pak/640x480"

cp "$REPO_ROOT/workspace/all/nextui/build/rg353ps/nextui.elf" \
    "$BUNDLE/.system/rg353ps/bin/nextui.elf"
cp "$REPO_ROOT/workspace/all/minarch/build/rg353ps/minarch.elf" \
    "$BUNDLE/.system/rg353ps/bin/minarch.elf"
cp "$REPO_ROOT/workspace/all/bootlogo/build/rg353ps/bootlogo.elf" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/bootlogo.elf"
cp "$REPO_ROOT/skeleton/EXTRAS/Tools/h700/Bootlogo.pak/launch.sh" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/launch.sh"
cp -a "$REPO_ROOT/skeleton/EXTRAS/Tools/h700/Bootlogo.pak/640x480/." \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/640x480/"
cp "$PREFIX_LOCAL/lib/libmsettings.so" "$BUNDLE/.system/rg353ps/lib/"
# minarch's generic RA build stages the codec/network dependencies alongside
# its executable; ship those exact sonames so the handheld need not supply them.
cp -a "$REPO_ROOT/workspace/all/minarch/build/rg353ps/"*.so* "$BUNDLE/.system/rg353ps/lib/"
for core in fceumm snes9x picodrive pcsx_rearmed; do
    if [ -s "$REPO_ROOT/workspace/rg353ps/cores/output/${core}_libretro.so" ]; then
        cp "$REPO_ROOT/workspace/rg353ps/cores/output/${core}_libretro.so" \
            "$BUNDLE/.system/rg353ps/cores/"
    fi
done

cp -a "$REPO_ROOT/skeleton/SYSTEM/res/." "$BUNDLE/.system/res/"
cp -a "$REPO_ROOT/skeleton/SYSTEM/h700/shaders/." "$BUNDLE/.system/rg353ps/shaders/"
cp "$REPO_ROOT/skeleton/SYSTEM/h700/system.cfg" "$BUNDLE/.system/rg353ps/system.cfg"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/paks/MinUI.pak/launch.sh" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak/launch.sh"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/bin/governor.sh" \
    "$BUNDLE/.system/rg353ps/bin/governor.sh"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/bin/run_hooks.sh" \
    "$BUNDLE/.system/rg353ps/bin/run_hooks.sh"

for item in "FC:fceumm" "SFC:snes9x" "MD:picodrive" "PS:pcsx_rearmed"; do
    pak=${item%%:*}
    core=${item#*:}
    if [ -s "$BUNDLE/.system/rg353ps/cores/${core}_libretro.so" ]; then
        cp -a "$REPO_ROOT/skeleton/SYSTEM/h700/paks/Emus/$pak.pak" \
            "$BUNDLE/.system/rg353ps/paks/Emus/$pak.pak"
    fi
done
cp "$REPO_ROOT/workspace/rg353ps/frontends/nextui/launch.sh" \
    "$BUNDLE/.baseos/frontends/nextui/launch.sh"

cat > "$BUNDLE/README-RG353PS.txt" <<'EOF'
NextUI for BaseOS on Anbernic RG353PS
=====================================

Extract this archive to the user-data partition mounted by BaseOS at /mnt/SDCARD.
The archive installs .baseos/frontends/nextui/launch.sh and the .system/res and
.system/rg353ps trees. BaseOS discovers the frontend on the next boot.

The bundle includes a Bootlogo.pak picker for the customizable /mnt/boot/bootlogo.bmp.
FC/NES, SFC/SNES, MD/Genesis and PS/PlayStation systems are included only when
their matching core builds. GB/GBC/GBA paks and cores are intentionally omitted.

BaseOS system boot files remain in the separate baseos-my355 repository.
EOF

chmod 0755 "$BUNDLE/.baseos/frontends/nextui/launch.sh" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak/launch.sh" \
    "$BUNDLE/.system/rg353ps/bin/governor.sh" \
    "$BUNDLE/.system/rg353ps/bin/run_hooks.sh" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/launch.sh" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/bootlogo.elf"
rm -f "$BUILD_OUT/baseos-rg353ps-nextui.zip" "$BUILD_OUT/baseos-rg353ps-nextui.zip.sha256"
(cd "$BUNDLE" && zip -qr "$BUILD_OUT/baseos-rg353ps-nextui.zip" .)
cd "$BUILD_OUT"
sha256sum baseos-rg353ps-nextui.zip > baseos-rg353ps-nextui.zip.sha256
echo "Bundle written to $BUILD_OUT/baseos-rg353ps-nextui.zip"
