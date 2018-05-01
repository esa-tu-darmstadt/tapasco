LLVM?=clang
CFLAGS+=-std=gnu11 -O3 -g -Wall -Werror -I$(TAPASCO_HOME)/common/include
LLVM_OPT+=-fsanitize=address $(CFLAGS)
CC=gcc

ifndef TAPASCO_HOME
$(error "TAPASCO_HOME is not set.")
endif

.PHONY:	clean

all:	gen_mem_test gen_queue_test

gen_mem_test:	gen_mem_test.c $(TAPASCO_HOME)/common/include/gen_mem.h
	$(LLVM) $(LLVM_OPT) $< -o $@

gen_queue_test:	gen_queue.c gen_queue_test.c
	$(CC) $(CFLAGS) $^ -pthread -lpthread -latomic -latomic_ops -o $@

clean:
	@rm gen_mem_test gen_queue_test

