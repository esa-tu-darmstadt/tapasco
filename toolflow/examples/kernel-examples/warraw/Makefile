CC ?= gcc
CFLAGS = -O3 -g -pedantic -std=gnu99 -Wall -Werror -Wno-unused-label

.PHONY: clean run

run:	warraw
	./warraw

warraw:	warraw.c warraw-tb.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	@rm -rf warraw *.o
