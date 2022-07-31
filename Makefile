.PHONY: hexdump clean sixel-%

LDLIBS    = $(shell pkg-config --libs libnfc-nci)
CFLAGS   := -Wall -Wextra -ggdb3 -Og -pthread

hexdump: main
	for a in '\x6A\x82' '\x90\x00' '\x90\x00'; do sleep 3; printf "$$a"; done | ./$< | od -Ad -tx1z
clean: F := main card
clean:
	-$(if $(strip $(wildcard $F)),$(RM) -- $F,)

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
