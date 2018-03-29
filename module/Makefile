ifndef TAPASCO_HOME
$(error "environment variable TAPASCO_HOME is not set - did you source TaPaSCo's setup.sh?")
endif

LINUX_HOME ?= /lib/modules/$(shell uname -r)/build
ifeq ($(ARCH), arm)
CROSS_COMPILE ?= arm-linux-gnueabihf-
endif

obj-m += tlkm.o
tlkm-objs := tlkm_module.o tlkm/tlkm_logging.o tlkm/tlkm_bus.o tlkm/tlkm.o tlkm/tlkm_ioctl.o tlkm/tlkm_device.o device/tlkm_perfc.o device/tlkm_perfc_miscdev.o device/tlkm_control.o device/tlkm_control_fops.o device/tlkm_device_ioctl.o zynq/tlkm_zynq_enumerate.o zynq/zynq_device.o

CPPFLAGS=-DPLATFORM_API_TAPASCO_STATUS_BASE=$(PLATFORM_API_TAPASCO_STATUS_BASE)
CPPFLAGS+=-I$(TAPASCO_HOME)/module -I$(TAPASCO_HOME)/module/device -I$(TAPASCO_HOME)/module/tlkm -I$(TAPASCO_HOME)/module/user

.PHONY:	all clean

all:
	make KCPPFLAGS="$(CPPFLAGS)" -C $(LINUX_HOME) M=$(PWD) modules

release:
	make KCPPFLAGS+="$(CPPFLAGS) -DNDEBUG -O3" -C $(LINUX_HOME) M=$(PWD) modules

clean:
	make -C $(LINUX_HOME) M=$(PWD) clean
