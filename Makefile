.PHONY: clean dump-apdu dump-hex

LDLIBS    = $(shell pkg-config --libs libnfc-nci)
CFLAGS   := -Wall -Wextra -ggdb3 -Og -pthread

dump-hex: main
	while sleep 3; do printf '\x6A\x82'; done | ./$< 5000 5
dump-apdu: main hexpipe apdu
	while sleep 1; do printf '\x6A\x82'; sleep 1; done | ./$< 5000 5 > apdu
clean: F := $(wildcard main apdu hexpipe *.s)
clean:
	-$(if $(strip $F),$(RM) -- $F,)
apdu:
	mkfifo -- $@

%.s: %.c
	$(CC) -S -Wall -Wextra -g0 -O3 -fno-plt -fno-asynchronous-unwind-tables -o $@ $<
