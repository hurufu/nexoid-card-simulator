.PHONY: clean dump-apdu dump-hex script

CPPFLAGS    :=
CFLAGS      := -Wall -Wextra -ggdb3 -Os -pipe
TARGET_ARCH := -march=native -mtune=native
LDFLAGS     := -fhardened
LDLIBS       = $(shell pkg-config --libs libnfc-nci)

dump-hex: main
	while sleep 3; do printf '\x6A\x82'; done | ./$< 5000 5 | od -Ad -tx1z
dump-apdu: main hexpipe apdu
	while sleep 1; do printf '\x6A\x82'; sleep 1; done | ./$< 5000 5 > apdu
clean: F := $(wildcard main apdu hexpipe unhexpipe debug *.s)
clean:
	-$(if $(strip $F),$(RM) -- $F,)
apdu debug:
	mkfifo -- $@
script: main card.exp debug hexpipe unhexpipe
	expect -- card.exp sh -c 'stty raw -echo; (./unhexpipe | ./$< 180000 5 | ./hexpipe) 2>debug'
hce: hce.c
	$(LINK.c) -o $@ $< $(LDLIBS)

%.s: %.c
	$(CC) -S -Wall -Wextra -g0 -O3 -fno-plt -fno-asynchronous-unwind-tables -o $@ $<
