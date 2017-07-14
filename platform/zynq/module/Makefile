LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm)
CROSS_COMPILE ?= arm-unknown-linux-gnueabihf-
endif

obj-m += tapasco-platform-zynq.o
tapasco-platform-zynq-objs := zynq_module.o zynq_device.o zynq_dmamgmt.o zynq_irq.o zynq_ioctl.o

.PHONY:	all clean

all:
	make -C $(LINUX_HOME) M=$(PWD) modules

release:
	KCPPFLAGS="-DNDEBUG -O3" make -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
	rm -rf test-alloc-dealloc

