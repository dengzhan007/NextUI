ifeq (,$(CROSS_COMPILE))
$(error missing CROSS_COMPILE for this toolchain)
endif
ifeq (,$(PREFIX_LOCAL))
$(error missing PREFIX_LOCAL for this toolchain)
endif

CC = $(CROSS_COMPILE)gcc
TARGET = msettings
CFLAGS = -I. -Wall -Wextra -fPIC -O2 -std=gnu11

.PHONY: all clean
all:
	mkdir -p "$(PREFIX_LOCAL)/include" "$(PREFIX_LOCAL)/lib"
	$(CC) $(CFLAGS) -shared -Wl,-soname,libmsettings.so -o "libmsettings.so" "msettings.c"
	cp "msettings.h" "$(PREFIX_LOCAL)/include/msettings.h"
	cp "libmsettings.so" "$(PREFIX_LOCAL)/lib/libmsettings.so"

clean:
	rm -f "libmsettings.so"
	rm -f "$(PREFIX_LOCAL)/include/msettings.h" "$(PREFIX_LOCAL)/lib/libmsettings.so"
