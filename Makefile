.PHONY: clean dump-apdu dump-hex script

CPPFLAGS    :=
CFLAGS      := -Wall -Wextra -ggdb3 -Os -pipe
TARGET_ARCH := -march=native -mtune=native
LDFLAGS     := -fhardened
LDLIBS       = $(shell pkg-config --libs libnfc-nci)
PROLOG      := scryer-prolog

.PHONY: start clean build

build: hce sim
start: start-hce start-sim
inter: start-hce start-int
start-hce: hce | in.fifo out.fifo
	exec ./$< >in.fifo <out.fifo
start-sim: sim | in.fifo out.fifo
	exec ./$<
start-int: | in.fifo out.fifo
	exec $(PROLOG) c.pl
clean: F := $(wildcard hce sim *.s *.o *.fifo)
clean:
	-$(if $(strip $F),$(RM) -- $F,)

hce: hce.c
	$(LINK.c) -o $@ $< $(LDLIBS)
sim: c.pl
	gplc --fast-math --no-top-level --min-fd-bips --no-fd-lib --strip -C '$(CFLAGS) $(TARGET_ARCH)' -L '$(LDFLAGS)' --output $@ $^

%.fifo:
	mkfifo -- $@
%.s: %.c
	$(CC) -S -Wall -Wextra -g0 -O3 -fno-plt -fno-asynchronous-unwind-tables -o $@ $<
