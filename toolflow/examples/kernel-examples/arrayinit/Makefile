CC ?= gcc
CFLAGS = -O3 -g -pedantic -std=gnu99 -Wall -Werror

.PHONY: clean run

run:	arrayinit
	./arrayinit

arrayinit:	arrayinit.c arrayinit-tb.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	@rm -rf arrayinit *.o
