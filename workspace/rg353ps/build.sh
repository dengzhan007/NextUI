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
        if [ "$core" = "pcsx_rearmed" ]; then
            echo "ERROR: required PlayStation core '$core' failed to build; refusing to publish a bundle without PS support." >&2
            exit 1
        fi
        echo "WARNING: core '$core' did not build; its system pak will be omitted."
    fi
done

# A successful compiler exit is not enough: the wrong upstream PLATFORM
# setting can produce a shared object named *_libretro.so with no Libretro API.
# Validate the exported entrypoints before copying anything into the bundle.
verify_libretro_core() {
    core_name=$1
    core_file="$REPO_ROOT/workspace/rg353ps/cores/output/${core_name}_libretro.so"
    [ -s "$core_file" ] || {
        echo "ERROR: required core output missing: $core_file" >&2
        exit 1
    }
    for symbol in retro_init retro_get_system_info retro_load_game; do
        if ! nm -D --defined-only "$core_file" 2>/dev/null | awk -v wanted="$symbol" '$NF == wanted { found=1 } END { exit !found }'; then
            echo "ERROR: $core_file does not export required Libretro symbol '$symbol'." >&2
            echo "The core was probably built with the wrong uppercase PLATFORM setting." >&2
            exit 1
        fi
    done
}
for core in fceumm snes9x picodrive pcsx_rearmed; do
    verify_libretro_core "$core"
done
if nm -D -u "$REPO_ROOT/workspace/rg353ps/cores/output/picodrive_libretro.so" 2>/dev/null |
    awk '$NF ~ /^emu_32x_startup(@.*)?$/ { found=1 } END { exit !found }'; then
    echo "ERROR: Picodrive core has unresolved symbol emu_32x_startup." >&2
    exit 1
fi

[ -s "$REPO_ROOT/workspace/rg353ps/cores/output/pcsx_rearmed_libretro.so" ] || {
    echo "ERROR: PlayStation core output is missing after core build." >&2
    exit 1
}
make -C "$REPO_ROOT/workspace/all/nextui" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/minarch" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/bootlogo" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/minput" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/.system/res" \
    "$BUNDLE/.system/rg353ps/bin" "$BUNDLE/.system/rg353ps/lib" \
    "$BUNDLE/.system/rg353ps/cores" "$BUNDLE/.system/rg353ps/shaders" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak" "$BUNDLE/.system/rg353ps/paks/Emus" \
    "$BUNDLE/.baseos/frontends/nextui" "$BUNDLE/Tools/rg353ps/Bootlogo.pak/640x480" \
    "$BUNDLE/Tools/rg353ps/Input.pak"

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
cp "$REPO_ROOT/workspace/all/minput/build/rg353ps/minput.elf" \
    "$BUNDLE/Tools/rg353ps/Input.pak/minput.elf"
printf '%s\n' '#!/bin/sh' 'cd "$(dirname "$0")"' './minput.elf' > "$BUNDLE/Tools/rg353ps/Input.pak/launch.sh"
cp "$PREFIX_LOCAL/lib/libmsettings.so" "$BUNDLE/.system/rg353ps/lib/"
# minarch's generic RA build stages the codec/network dependencies alongside
# its executable; ship those exact sonames so the handheld need not supply them.
cp -a "$REPO_ROOT/workspace/all/minarch/build/rg353ps/"*.so* "$BUNDLE/.system/rg353ps/lib/"
# nextui.elf uses SDL2_image and SDL2_ttf directly. These libraries are
# installed in the Alpine build container, but unlike minarch's staged
# dependencies they were not copied into the portable RG353PS bundle.
# Include their runtime dependencies too, while leaving core system libraries
# (musl, the dynamic loader, and the base SDL2 runtime) to BaseOS.
for pattern in \
    'libSDL2_image-2.0.so*' 'libSDL2_ttf-2.0.so*' \
    'libpng16.so*' 'libjpeg.so*' 'libwebp*.so*' 'libtiff.so*' \
    'libfreetype.so*' 'libharfbuzz.so*' 'libbrotlidec.so*' \
    'libbrotlicommon.so*' 'libsharpyuv.so*' 'libjbig.so*' \
    'libdeflate.so*' 'libavif.so*' 'libbz2.so*' 'libintl.so*'; do
    for library in /usr/lib/$pattern; do
        [ -e "$library" ] || continue
        cp -a "$library" "$BUNDLE/.system/rg353ps/lib/"
    done
done
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
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/bin/suspend" \
    "$BUNDLE/.system/rg353ps/bin/suspend"

for item in "FC:fceumm" "SFC:snes9x" "MD:picodrive" "PS:pcsx_rearmed"; do
    pak=${item%%:*}
    core=${item#*:}
    if [ -s "$BUNDLE/.system/rg353ps/cores/${core}_libretro.so" ]; then
        cp -a "$REPO_ROOT/skeleton/SYSTEM/h700/paks/Emus/$pak.pak" \
            "$BUNDLE/.system/rg353ps/paks/Emus/$pak.pak"
    fi
done
# Do not publish a bundle that silently drops the PS system menu because the
# core or the inherited PAK launcher was missing.
[ -s "$BUNDLE/.system/rg353ps/cores/pcsx_rearmed_libretro.so" ] || {
    echo "ERROR: bundle is missing pcsx_rearmed_libretro.so" >&2
    exit 1
}
[ -f "$BUNDLE/.system/rg353ps/paks/Emus/PS.pak/launch.sh" ] || {
    echo "ERROR: bundle is missing the PS emulator PAK launcher" >&2
    exit 1
}
cp "$REPO_ROOT/workspace/rg353ps/frontends/nextui/launch.sh" \
    "$BUNDLE/.baseos/frontends/nextui/launch.sh"

cat > "$BUNDLE/README-RG353PS.txt" <<'EOF'
NextUI for BaseOS on Anbernic RG353PS
=====================================

Extract this archive to the user-data partition mounted by BaseOS at /mnt/SDCARD.
The archive installs .baseos/frontends/nextui/launch.sh and the .system/res and
.system/rg353ps trees. BaseOS discovers the frontend on the next boot.

The RG353PS suspend helper explicitly selects Linux `deep` sleep before requesting
`state=mem`. Each suspend attempt writes a separate diagnostic report to
`/mnt/boot/rg353ps-suspend-test-deep-<timestamp>.txt`; reports include the selected
kernel sleep mode, suspend statistics, wakeup IRQ, elapsed time, and relevant kernel
messages captured after resume. This makes a black screen alone insufficient to
count as a successful suspend test.

The bundle includes a Bootlogo.pak picker for the customizable /mnt/boot/bootlogo.bmp.
It also includes Tools/rg353ps/Input.pak for on-screen controller testing. Button/axis
changes are appended to /mnt/SDCARD/rg353ps-input-test.log; quit with START+SELECT.
FC/NES, SFC/SNES, MD/Genesis and PS/PlayStation systems are included only when
their matching core builds. GB/GBC/GBA paks and cores are intentionally omitted.

BaseOS system boot files remain in the separate baseos-my355 repository.
EOF

chmod 0755 "$BUNDLE/.baseos/frontends/nextui/launch.sh" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak/launch.sh" \
    "$BUNDLE/.system/rg353ps/bin/governor.sh" \
    "$BUNDLE/.system/rg353ps/bin/run_hooks.sh" \
    "$BUNDLE/.system/rg353ps/bin/suspend" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/launch.sh" \
    "$BUNDLE/Tools/rg353ps/Bootlogo.pak/bootlogo.elf" \
    "$BUNDLE/Tools/rg353ps/Input.pak/launch.sh" \
    "$BUNDLE/Tools/rg353ps/Input.pak/minput.elf"
rm -f "$BUILD_OUT/baseos-rg353ps-nextui.zip" "$BUILD_OUT/baseos-rg353ps-nextui.zip.sha256"
(cd "$BUNDLE" && zip -qr "$BUILD_OUT/baseos-rg353ps-nextui.zip" .)
cd "$BUILD_OUT"
sha256sum baseos-rg353ps-nextui.zip > baseos-rg353ps-nextui.zip.sha256
echo "Bundle written to $BUILD_OUT/baseos-rg353ps-nextui.zip"
