# Keep this initial profile focused on systems outside the Game Boy family.
CORES = fceumm
CORES += snes9x
CORES += picodrive
CORES += pcsx_rearmed

fceumm_REPO = https://github.com/libretro/libretro-fceumm

snes9x_REPO = https://github.com/libretro/snes9x
snes9x_CORE = snes9x_libretro.so
snes9x_BUILD_PATH = snes9x/libretro

picodrive_REPO = https://github.com/irixxxx/picodrive
picodrive_MAKEFILE = Makefile.libretro
picodrive_HASH = b0be121b7d58d6ee1ee2809974e62893c80a8264

pcsx_rearmed_REPO = https://github.com/libretro/pcsx_rearmed
pcsx_rearmed_MAKEFILE = Makefile.libretro
pcsx_rearmed_SUBMODULES = frontend/libpicofe

include ../../all/cores/makefile
