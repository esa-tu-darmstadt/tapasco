HWSWCOSIM ?= ../../hwswcosim
CC ?= gcc
CFLAGS += -O3 -g -I$(HWSWCOSIM)/include -pedantic -Wall -Werror -std=gnu99
LDFLAGS += -L$(HWSWCOSIM)/lib -lrcu-client

.PHONY: clean

rcu-client: client.c kernel_desc.c
	$(CC) $(CFLAGS) -o $@ $(LDFLAGS) $^

clean:
	rm -rf rcu-client
