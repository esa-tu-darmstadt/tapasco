CC ?= gcc
CFLAGS = -O3 -g -pedantic -std=gnu99 -Wall -Werror

.PHONY: clean run

run:	arraysum
	./arraysum

arraysum:	arraysum.c arraysum-tb.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	@rm -rf arraysum *.o
