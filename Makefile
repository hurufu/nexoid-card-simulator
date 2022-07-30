.PHONY: run clean

LDLIBS  = $(shell pkg-config --libs libnfc-nci)
CFLAGS := -Wall -Wextra -ggdb3 -Og -pthread

run: main
	printf '\x90\x00' | ./$< | od -Ad -tx1z
clean: F := main
clean:
	-$(if $(strip $(wildcard $F)),$(RM) -- $F,)
