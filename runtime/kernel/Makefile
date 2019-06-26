ifndef TAPASCO_HOME_RUNTIME
$(error "environment variable TAPASCO_HOME_RUNTIME is not set - did you source TaPaSCo's setup.sh?")
endif

ifdef NPERFC
$(info "environment variable NPERFC is set, building with -DNPERFC")
CPPFLAGS+=-DNPERFC
endif

ifndef LINUX_HOME
LINUX_HOME:=/lib/modules/$(shell uname -r)/build
endif

ifeq ($(ARCH), arm)
CROSS_COMPILE?=arm-linux-gnueabihf-
endif

CPPFLAGS+=-Werror -I$(TAPASCO_HOME_RUNTIME)/kernel \
				  -I$(TAPASCO_HOME_RUNTIME)/kernel/device \
				  -I$(TAPASCO_HOME_RUNTIME)/kernel/tlkm \
				  -I$(TAPASCO_HOME_RUNTIME)/kernel/user \
				  -I$(TAPASCO_HOME_RUNTIME)/platform/include \
				  -I$(TAPASCO_HOME_RUNTIME)/kernel/hsa \
				  -I$(TAPASCO_HOME_RUNTIME)/kernel/nanopb \
				  -DPB_SYSTEM_HEADER=\<pb_system.h\>

.PHONY:	all clean

all:
	make KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(TAPASCO_HOME_RUNTIME)/kernel modules

release:
	make KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(TAPASCO_HOME_RUNTIME)/kernel modules

clean:
	make -C $(LINUX_HOME) M=$(TAPASCO_HOME_RUNTIME)/kernel clean
