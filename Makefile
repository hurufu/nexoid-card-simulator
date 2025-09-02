CPPFLAGS       :=
CFLAGS         := -Wall -Wextra -ggdb3 -Os -pipe
TARGET_ARCH    := -march=native -mtune=native
ASFLAGS        :=
TARGET_MACH    := --64
LDFLAGS        := -fhardened -Whardened
PROLOG         := scryer-prolog
GPROLOG_LIBDIR := /usr/share/gprolog/lib

.PHONY: start clean build start-hce start-int inter

build: hce sim
start: start-hce start-sim
inter: start-hce start-int
start-hce: hce | in.fifo out.fifo
	exec ./$< >in.fifo <out.fifo
start-sim: sim | in.fifo out.fifo
	exec ./$<
start-int: | in.fifo out.fifo
	exec $(PROLOG) c.pl
clean: F := $(wildcard hce sim *.s *.o *.fifo *.wam *.ma)
clean:
	$(if $(strip $F),$(RM) -- $F)

hce: LDLIBS = $(shell pkg-config --libs libnfc-nci)
hce: hce.c
	$(LINK.c) -o $@ $< $(LDLIBS)
sim: LDLIBS  := $(GPROLOG_LIBDIR)/all_pl_bips.o -lbips_pl -lengine_pl -llinedit -lm
sim: LDFLAGS += -L$(GPROLOG_LIBDIR)
sim: sim.o
	$(LINK.o) -o $@ $< $(LDLIBS)

%.wam: %.pl
	pl2wam --wam-for-native --fast-math -o $@ $<
%.ma: %.wam
	wam2ma -o $@ $<
%.s: %.ma
	ma2asm -o $@ $<
%.fifo:
	mkfifo -- $@
