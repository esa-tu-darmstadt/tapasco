LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm64)
CROSS_COMPILE ?= aarch64-linux-gnu-
endif

obj-m += tapasco-platform-zynqmp.o
tapasco-platform-zynqmp-objs := zynqmp_module.o zynqmp_device.o zynqmp_dmamgmt.o zynqmp_irq.o zynqmp_ioctl.o

.PHONY:	all clean

all:
	make -C $(LINUX_HOME) M=$(PWD) modules

release:
	KCPPFLAGS="-DNDEBUG -O3" make -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
	rm -rf test-alloc-dealloc

