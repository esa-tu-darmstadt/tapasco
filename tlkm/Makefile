ifndef TAPASCO_HOME
$(error "environment variable TAPASCO_HOME is not set - did you source TaPaSCo's setup.sh?")
endif

LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm)
CROSS_COMPILE ?= arm-linux-gnueabihf-
endif

obj-m += tlkm.o
tlkm-objs := \
	tlkm_module.o \
	tlkm/tlkm_logging.o \
	tlkm/tlkm_bus.o \
	tlkm/tlkm.o \
	tlkm/tlkm_ioctl.o \
	tlkm/tlkm_device.o \
	tlkm/tlkm_status.o \
	tlkm/tlkm_platform.o \
	device/tlkm_perfc.o \
	device/tlkm_perfc_miscdev.o \
	device/tlkm_control.o \
	device/tlkm_device_rw.o \
	device/tlkm_device_ioctl.o \
	device/tlkm_device_mmap.o \
	zynq/zynq_device.o \
	zynq/zynq_ioctl.o \
	zynq/zynq_dmamgmt.o \
	zynq/zynq_irq.o \
	pcie/pcie.o \
	pcie/pcie_device.o \
	pcie/pcie_irq.o \
	pcie/pcie_ioctl.o \
	dma/tlkm_dma.o \
	dma/dual_dma.o \
	dma/blue_dma.o


CPPFLAGS+=-I$(TAPASCO_HOME)/tlkm -I$(TAPASCO_HOME)/tlkm/device -I$(TAPASCO_HOME)/tlkm/tlkm -I$(TAPASCO_HOME)/tlkm/user -I$(TAPASCO_HOME)/platform/include

.PHONY:	all clean

all:
	make KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(PWD) modules

release:
	make KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
