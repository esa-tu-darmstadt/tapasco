LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm)
CROSS_COMPILE ?= arm-linux-gnueabihf-
endif

obj-m += tlkm.o
tlkm-objs := tlkm_module.o tlkm_logging.o tlkm_perfc.o tlkm_perfc_miscdev.o tlkm_async.o

CPPFLAGS=-DPLATFORM_API_TAPASCO_STATUS_BASE=$(PLATFORM_API_TAPASCO_STATUS_BASE)
CPPFLAGS+=-I$(TAPASCO_HOME)/module

.PHONY:	all clean

all:
	make KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(PWD) modules

release:
	make KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
