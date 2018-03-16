PLATFORM_API_TAPASCO_STATUS_BASE?=0x40000000UL
LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm)
CROSS_COMPILE ?= arm-unknown-linux-gnueabihf-
endif

obj-m += tapasco-platform-zynq.o
tapasco-platform-zynq-objs := zynq_module.o zynq_device.o zynq_dmamgmt.o zynq_irq.o zynq_ioctl.o zynq_async.o

CPPFLAGS=-DPLATFORM_API_TAPASCO_STATUS_BASE=$(PLATFORM_API_TAPASCO_STATUS_BASE)
CPPFLAGS+=-I$(TAPASCO_HOME)/platform/common/include

.PHONY:	all clean

all:
	make KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(PWD) modules

release:
	make KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
	rm -rf test-alloc-dealloc

