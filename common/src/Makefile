LLVM?=clang
LLVM_OPT+=-fsanitize=address -O3 -g -Wall -Werror -I$(TAPASCO_HOME)/common/include

ifndef TAPASCO_HOME
$(error "TAPASCO_HOME is not set.")
endif

.PHONY:	clean

gen_mem_test:	gen_mem_test.c $(TAPASCO_HOME)/common/include/gen_mem.h
	$(LLVM) $(LLVM_OPT) $< -o $@

clean:
	@rm gen_mem_test

