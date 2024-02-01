ifdef NPERFC
$(info "environment variable NPERFC is set, building with -DNPERFC")
CPPFLAGS+=-DNPERFC
endif

ifndef LINUX_HOME
LINUX_HOME:=/lib/modules/$(shell uname -r)/build
endif

ifeq ($(ARCH), arm)
CROSS_COMPILE?=arm-linux-gnueabihf-
export CROSS_COMPILE
endif

ifeq ($(EN_SVM), 1)
CPPFLAGS+=-DEN_SVM
endif

ifeq ($(ENABLE_SIM),y)
CPPFLAGS+=-DENABLE_SIM
endif

MODULE_DIR := $(PWD)

CPPFLAGS+=-Werror -Wno-missing-attributes -I$(MODULE_DIR) \
				  -I$(MODULE_DIR)/device \
				  -I$(MODULE_DIR)/tlkm \
				  -I$(MODULE_DIR)/user \
				  -I$(MODULE_DIR)/nanopb \
				  -DPB_SYSTEM_HEADER=\<pb_system.h\>

# check if we are on aarch64 with at least GCC 10 and add compiler flag
AARCH64_CC:=$(findstring aarch64,$(shell $(CC) -dumpmachine))
ifeq ($(shell expr `$(CC) -dumpversion | cut -f1 -d.` \>= 10),1)
GCC_10:=1
endif
ifneq ($(and $(AARCH64_CC),$(GCC_10)),)
CPPFLAGS+=-mno-outline-atomics
endif

.PHONY:	all clean

all:
	$(MAKE) KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(MODULE_DIR) modules

release:
	$(MAKE) KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(MODULE_DIR) modules

clean:
	$(MAKE) -C $(LINUX_HOME) M=$(MODULE_DIR) clean
