.PHONY: run clean

LDLIBS  = $(shell pkg-config --libs libnfc-nci)
CFLAGS := -Wall -Wextra -ggdb3 -Og -pthread

run: main
	while sleep 1; do printf '\x90\x00'; done | ./$< | od -Ad -tx1z
clean: F := main
clean:
	-$(if $(strip $(wildcard $F)),$(RM) -- $F,)
