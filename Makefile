.PHONY: hexdump clean script

LDLIBS    = $(shell pkg-config --libs libnfc-nci)
CFLAGS   := -Wall -Wextra -ggdb3 -Og -pthread

script: main card.exp
	expect -d -- card.exp ./$< 5000
hexdump: main
	for a in '\x6A\x82' '\x90\x00' '\x90\x00'; do sleep 3; printf "$$a"; done | ./$< | od -Ad -tx1z
clean: F := main
clean:
	-$(if $(strip $(wildcard $F)),$(RM) -- $F,)
