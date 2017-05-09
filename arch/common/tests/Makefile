CC ?= gcc
CFLAGS = -O3 -g -std=gnu99 -I$(ARCH_INCLUDE) -I$(PLAT_INCLUDE) -I$(CMN_INCLUDE)
LDFLAGS = -lcheck -pthread -latomic

ARCH_SRC = ../src
ARCH_INCLUDE = ../include
PLAT_INCLUDE = $(TAPASCO_HOME)/platform/common/include
CMN_INCLUDE = $(TAPASCO_HOME)/common/include
CMN_SRC = $(TAPASCO_HOME)/common/src

SRCS = $(wildcard *.c)
OBJS = $(patsubst %.c,%.o,$(SRCS))
ASRCS = $(ARCH_SRC)/tapasco_functions.c $(ARCH_SRC)/tapasco_jobs.c $(ARCH_SRC)/tapasco_logging.c
AOBJS = $(patsubst $(ARCH_SRC)/%.c,%.o,$(ASRCS))
CSRCS = $(CMN_SRC)/gen_queue.c
COBJS = $(patsubst $(CMN_SRC)/%.c,%.o,$(CSRCS))

.PHONY : all clean test

%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : $(ARCH_SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o : $(CMN_SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

all : tapasco_common_test

tapasco_common_test : $(OBJS) $(AOBJS) $(COBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(AOBJS) $(COBJS)

test : all
	./tapasco_common_test

clean :
	rm -rf tapasco_common_test *.o
