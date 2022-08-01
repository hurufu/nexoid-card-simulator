.PHONY: clean sixel-% dump-apdu dump-hex

LDLIBS    = $(shell pkg-config --libs libnfc-nci)
CFLAGS   := -Wall -Wextra -ggdb3 -Og -pthread

dump-hex: main
	while sleep 3; do printf '\x6A\x82'; done | ./$< 5000 5 | od -Ad -tx1z
dump-apdu: main hexcat apdu
	while sleep 1; do printf '\x6A\x82'; sleep 1; done | ./$< 5000 5 > apdu
clean: F := main card apdu hexcat
clean:
	-$(if $(strip $(wildcard $F)),$(RM) -- $F,)
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
