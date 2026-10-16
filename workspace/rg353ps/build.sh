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

apk add --no-cache build-base make git pkgconf zip \
    sdl2-dev sdl2_image-dev sdl2_ttf-dev mesa-dev freetype-dev \
    libsamplerate-dev libzip-dev lz4-dev alsa-lib-dev zlib-dev bzip2-dev xz-dev zstd-dev

PREFIX_LOCAL="$REPO_ROOT/workspace/rg353ps/build/prefix"
BUILD_OUT="$REPO_ROOT/workspace/rg353ps/build"
BUNDLE="$BUILD_OUT/baseos-rg353ps-nextui"
mkdir -p "$PREFIX_LOCAL/include" "$PREFIX_LOCAL/lib"
[ -f "$REPO_ROOT/workspace/hash.txt" ] || echo rg353ps > "$REPO_ROOT/workspace/hash.txt"

make -C "$REPO_ROOT/workspace/rg353ps/libmsettings" \
    CROSS_COMPILE=/usr/bin/ PREFIX_LOCAL="$PREFIX_LOCAL" PREFIX=/usr
make -C "$REPO_ROOT/workspace/rg353ps/cores" \
    PLATFORM=rg353ps CORE_BUILD_PLATFORM=unix CROSS_COMPILE=/usr/bin/ \
    PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL" cores
make -C "$REPO_ROOT/workspace/all/nextui" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"
make -C "$REPO_ROOT/workspace/all/minarch" \
    PLATFORM=rg353ps CROSS_COMPILE=/usr/bin/ PREFIX=/usr PREFIX_LOCAL="$PREFIX_LOCAL"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/.system/res" \
    "$BUNDLE/.system/rg353ps/bin" "$BUNDLE/.system/rg353ps/lib" \
    "$BUNDLE/.system/rg353ps/cores" "$BUNDLE/.system/rg353ps/shaders" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak" "$BUNDLE/.system/rg353ps/paks/Emus" \
    "$BUNDLE/.baseos/frontends/nextui"

cp "$REPO_ROOT/workspace/all/nextui/build/rg353ps/nextui.elf" \
    "$BUNDLE/.system/rg353ps/bin/nextui.elf"
cp "$REPO_ROOT/workspace/all/minarch/build/rg353ps/minarch.elf" \
    "$BUNDLE/.system/rg353ps/bin/minarch.elf"
cp "$PREFIX_LOCAL/lib/libmsettings.so" "$BUNDLE/.system/rg353ps/lib/"
cp "$REPO_ROOT/workspace/rg353ps/cores/output/fceumm_libretro.so" \
    "$BUNDLE/.system/rg353ps/cores/"
cp "$REPO_ROOT/workspace/rg353ps/cores/output/snes9x_libretro.so" \
    "$BUNDLE/.system/rg353ps/cores/"
cp "$REPO_ROOT/workspace/rg353ps/cores/output/picodrive_libretro.so" \
    "$BUNDLE/.system/rg353ps/cores/"
cp "$REPO_ROOT/workspace/rg353ps/cores/output/pcsx_rearmed_libretro.so" \
    "$BUNDLE/.system/rg353ps/cores/"

cp -a "$REPO_ROOT/skeleton/SYSTEM/res/." "$BUNDLE/.system/res/"
cp -a "$REPO_ROOT/skeleton/SYSTEM/h700/shaders/." "$BUNDLE/.system/rg353ps/shaders/"
cp "$REPO_ROOT/skeleton/SYSTEM/h700/system.cfg" "$BUNDLE/.system/rg353ps/system.cfg"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/paks/MinUI.pak/launch.sh" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak/launch.sh"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/bin/governor.sh" \
    "$BUNDLE/.system/rg353ps/bin/governor.sh"
cp "$REPO_ROOT/skeleton/SYSTEM/rg353ps/bin/run_hooks.sh" \
    "$BUNDLE/.system/rg353ps/bin/run_hooks.sh"

for pak in FC SFC MD PS; do
    cp -a "$REPO_ROOT/skeleton/SYSTEM/h700/paks/Emus/$pak.pak" \
        "$BUNDLE/.system/rg353ps/paks/Emus/$pak.pak"
done
cp "$REPO_ROOT/workspace/rg353ps/frontends/nextui/launch.sh" \
    "$BUNDLE/.baseos/frontends/nextui/launch.sh"

cat > "$BUNDLE/README-RG353PS.txt" <<'EOF'
NextUI for BaseOS on Anbernic RG353PS
=====================================

Extract this archive to the user-data partition mounted by BaseOS at /mnt/SDCARD.
The archive installs .baseos/frontends/nextui/launch.sh and the .system/res and
.system/rg353ps trees. BaseOS discovers the frontend on the next boot.

This profile includes FC/NES, SFC/SNES, MD/Genesis and PS/PlayStation paks and
matching FCEUmm, Snes9x, PicoDrive and PCSX-ReARMed cores. GB/GBC/GBA paks and
cores are intentionally excluded from this RG353PS profile.

BaseOS system boot files remain in the separate baseos-my355 repository.
EOF

chmod 0755 "$BUNDLE/.baseos/frontends/nextui/launch.sh" \
    "$BUNDLE/.system/rg353ps/paks/MinUI.pak/launch.sh" \
    "$BUNDLE/.system/rg353ps/bin/governor.sh" \
    "$BUNDLE/.system/rg353ps/bin/run_hooks.sh"
rm -f "$BUILD_OUT/baseos-rg353ps-nextui.zip" "$BUILD_OUT/baseos-rg353ps-nextui.zip.sha256"
(cd "$BUNDLE" && zip -qr "$BUILD_OUT/baseos-rg353ps-nextui.zip" .)
cd "$BUILD_OUT"
sha256sum baseos-rg353ps-nextui.zip > baseos-rg353ps-nextui.zip.sha256
echo "Bundle written to $BUILD_OUT/baseos-rg353ps-nextui.zip"
