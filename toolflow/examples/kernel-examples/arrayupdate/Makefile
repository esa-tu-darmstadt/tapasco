CC ?= gcc
CFLAGS = -O3 -g -pedantic -std=gnu99 -Wall -Werror

.PHONY: clean run

run:	arrayupdate
	./arrayupdate

arrayupdate:	arrayupdate.c arrayupdate-tb.c
	$(CC) $(CFLAGS) -o $@ $^

clean:
	@rm -rf arrayupdate *.o
