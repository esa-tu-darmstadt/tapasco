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

MODULE_DIR := $(PWD)

CPPFLAGS+=-Werror -I$(MODULE_DIR) \
				  -I$(MODULE_DIR)/device \
				  -I$(MODULE_DIR)/tlkm \
				  -I$(MODULE_DIR)/user \
				  -I$(MODULE_DIR)/hsa \
				  -I$(MODULE_DIR)/nanopb \
				  -DPB_SYSTEM_HEADER=\<pb_system.h\>

.PHONY:	all clean

all:
	$(MAKE) KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(MODULE_DIR) modules

release:
	$(MAKE) KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(MODULE_DIR) modules

clean:
	$(MAKE) -C $(LINUX_HOME) M=$(MODULE_DIR) clean
