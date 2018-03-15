CC ?= gcc
CFLAGS = -O3 -g -std=gnu99 -I$(ARCH_INCLUDE) -I$(PLAT_INCLUDE) -I$(CMN_INCLUDE) -I$(LIBCHECK_INCLUDE)
LDFLAGS = -L$(LIBCHECK_LIB) -lcheck -pthread -latomic

AXI4MM_SRC = ../../axi4mm/src
ARCH_SRC = ../src
ARCH_INCLUDE = ../include
PLAT_INCLUDE = $(TAPASCO_HOME)/platform/common/include
PLAT_SRC = $(TAPASCO_HOME)/platform/common/src
CMN_INCLUDE = $(TAPASCO_HOME)/common/include
CMN_SRC = $(TAPASCO_HOME)/common/src

LIBCHECK_BASE = $(PWD)/libcheck
LIBCHECK_INCLUDE = $(LIBCHECK_BASE)/include
LIBCHECK_LIB = $(LIBCHECK_BASE)/lib

SRCS = $(wildcard *.c)
OBJS = $(patsubst %.c,%.o,$(SRCS))
XSRCS = $(AXI4MM_SRC)/tapasco_regs.c
XOBJS = $(patsubst $(AXI4MM_SRC)/%.c,%.o,$(XSRCS))
ASRCS = $(ARCH_SRC)/tapasco_pemgmt.c $(ARCH_SRC)/tapasco_jobs.c $(ARCH_SRC)/tapasco_logging.c
AOBJS = $(patsubst $(ARCH_SRC)/%.c,%.o,$(ASRCS))
PSRCS = $(PLAT_SRC)/platform_errors.c
POBJS = $(patsubst $(PLAT_SRC)/%.c,%.o,$(PSRCS))
CSRCS = $(CMN_SRC)/gen_queue.c
COBJS = $(patsubst $(CMN_SRC)/%.c,%.o,$(CSRCS))

.PHONY : all clean test

%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : $(ARCH_SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : $(PLAT_SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : $(CMN_SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : ../../axi4mm/src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

all : libcheck tapasco_common_test

tapasco_common_test : $(OBJS) $(AOBJS) $(POBJS) $(COBJS) $(XOBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(AOBJS) $(POBJS) $(COBJS) $(XOBJS)

test : all
	./tapasco_common_test

libcheck:
	git clone https://github.com/libcheck/check.git && pushd check && autoreconf --install && ./configure --prefix=$(LIBCHECK_BASE) && make && make install

clean :
	rm -rf tapasco_common_test *.o

dist-clean:	clean
	rm -rf $(LIBCHECK_BASE) check
