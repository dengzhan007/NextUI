# Minimal platform target used by the RG353PS bundle builder.
ifeq (,$(PLATFORM))
PLATFORM=rg353ps
endif
.PHONY: all early clean
all:
	@echo "RG353PS platform-specific helpers are built by workspace/rg353ps/build.sh"
early:
	@echo "RG353PS uses the BaseOS SDL2/Mesa runtime"
clean:
	rm -f other/*.o
