CPPFLAGS       :=
CFLAGS         := -Wall -Wextra -ggdb3 -Os -pipe
TARGET_ARCH    := -march=native -mtune=native
ASFLAGS        :=
TARGET_MACH    := --64
LDFLAGS        := -fhardened -Whardened
PROLOG         := scryer
GPROLOG_LIBDIR := /usr/share/gprolog/lib
CARD           := discover

.PHONY: start clean build start-hce start-int inter check
.INTERMEDIATE: all-init.pl all-ut.pl

vpath %.pl cards compat

build: hce sim
start: start-hce start-sim
inter: start-hce start-int
start-hce: hce | in.fifo out.fifo
	exec ./$< >in.fifo <out.fifo
start-sim: sim | in.fifo out.fifo
	exec ./$<
start-int: all-init.pl | in.fifo out.fifo
	exec prologs -p $(PROLOG) -g main $<
check: all-ut.pl
	exec prologs -p $(PROLOG) -g '(test,!;true)' $<
clean: F := $(wildcard hce sim *.s *.o *.fifo *.wam *.ma)
clean:
	$(if $(strip $F),$(RM) -- $F)

hce: LDLIBS = $(shell pkg-config --libs libnfc-nci)
hce: hce.c
	$(LINK.c) -o $@ $< $(LDLIBS)
sim: LDLIBS  := $(GPROLOG_LIBDIR)/all_pl_bips.o -lbips_pl -lengine_pl -llinedit -lm
sim: LDFLAGS += -L$(GPROLOG_LIBDIR)
sim: init.o sim.o $(CARD).o gnu.o
	$(LINK.o) -o $@ $^ $(LDLIBS)
all-%.pl: $(PROLOG).pl %.pl sim.pl $(CARD).pl
	cat $^ > $@

%.wam: %.pl
	pl2wam --wam-for-native --fast-math -o $@ $<
%.ma: %.wam
	wam2ma -o $@ $<
%.s: %.ma
	ma2asm -o $@ $<
%.fifo:
	mkfifo -- $@
