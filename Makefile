CPPFLAGS       :=
CFLAGS         := -Wall -Wextra -ggdb3 -Os -pipe
TARGET_ARCH    := -march=native -mtune=native
ASFLAGS        :=
TARGET_MACH    := --64
LDFLAGS        := -fhardened -Whardened
PROLOG         := scryer-prolog
GPROLOG_LIBDIR := /usr/share/gprolog/lib
CARD           := visa

COMPAT_scryer-prolog := scryer
COMPAT_swipl         := swi
COMPAT_gprolog       := gpl
COMPAT               := $(COMPAT_$(PROLOG)).pl

.PHONY: start clean build start-hce start-int inter check

vpath %.pl cards compat

build: hce sim
start: start-hce start-sim
inter: start-hce start-int
start-hce: hce | in.fifo out.fifo
	exec ./$< >in.fifo <out.fifo
start-sim: sim | in.fifo out.fifo
	exec ./$<
start-int: sim.pl $(CARD).pl $(COMPAT) init.pl | in.fifo out.fifo
	exec $(PROLOG) $^
check: sim.pl $(CARD).pl $(COMPAT) ut.pl
	exec $(PROLOG) -g 'halt' $^
clean: F := $(wildcard hce sim *.s *.o *.fifo *.wam *.ma)
clean:
	$(if $(strip $F),$(RM) -- $F)

hce: LDLIBS = $(shell pkg-config --libs libnfc-nci)
hce: hce.c
	$(LINK.c) -o $@ $< $(LDLIBS)
sim: LDLIBS  := $(GPROLOG_LIBDIR)/all_pl_bips.o -lbips_pl -lengine_pl -llinedit -lm
sim: LDFLAGS += -L$(GPROLOG_LIBDIR)
sim: sim.o $(CARD).o sim-init.o sim-init-gpl.o
	$(LINK.o) -o $@ $^ $(LDLIBS)

%.wam: %.pl
	pl2wam --wam-for-native --fast-math -o $@ $<
%.ma: %.wam
	wam2ma -o $@ $<
%.s: %.ma
	ma2asm -o $@ $<
%.fifo:
	mkfifo -- $@
