.PHONY: clean sixel-% dump-apdu dump-hex

LDLIBS    = $(shell pkg-config --libs libnfc-nci)
CFLAGS   := -Wall -Wextra -ggdb3 -Og -pthread

dump-hex: main
	while sleep 3; do printf '\x6A\x82'; done | ./$< 5000 5 | od -Ad -tx1z
dump-apdu: main hexpipe apdu
	while sleep 1; do printf '\x6A\x82'; sleep 1; done | ./$< 5000 5 > apdu
card-test: main card apdu
	od -tx1z < apdu & while sleep 1; do printf '\x90\x00'; sleep 1; printf '\x6A\x82'; done | ./$< 5000 5 | tee apdu | ./card & wait
clean: F := $(wildcard main card apdu hexpipe *.s)
clean:
	-$(if $(strip $F),$(RM) -- $F,)
apdu:
	mkfifo -- $@

%.c: %.rl
	ragel -C -o $@ $<
%.dot: %.rl
	ragel -p -V -o $@ $<
%.svg: %.dot
	dot -Tsvg $< >$@
%.sixel: %.svg
	convert $< $@
sixel-%: %.rl
	ragel -p -V $< | dot -Tsvg | convert svg:- sixel:-
%.s: %.c
	$(CC) -S -Wall -Wextra -g0 -O3 -fno-plt -fno-asynchronous-unwind-tables -o $@ $<
