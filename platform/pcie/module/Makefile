# Makefile to build the ffLink module, which can be loaded with 'sudo insmod ffLink.ko' afterwards
# make should not be run as root, otherwise generated files cannot be removed correctly

# Name of Kernel module
obj-m := ffLink.o

# composition of files needed to compile
# one can exchange dual_dma_ctrl with cdma_dma_ctrl, when dma engine from Xilinx is used
ffLink-objs := pcie_device.o blue_dma_ctrl.o char_device_dma.o char_device_user.o ffLink_driver.o dual_dma_ctrl.o dma_ctrl.o async.o

# Path to kernel headers for compilation (path to home can be specific to os)
LNX=$(shell uname -r)

LINUX_HOME?=/lib/modules/$(LNX)/build

INSTDIR := /lib/modules/$(LNX)/kernel/drivers/net
DRV_NAME := ffLink

# Comment/uncomment the following line to disable/enable debugging
#DEBUG = y
#DEBUG_VERBOSE = y

# Add your debugging flag (or not)
ifeq ($(DEBUG_VERBOSE),y)
  DEBUGFLAGS+=-DDEBUG_VERBOSE -DDEBUG
  COMPILEFLAGS=-Wall -g -O0
else ifeq ($(DEBUG),y)
  DEBUGFLAGS=-DDEBUG
  COMPILEFLAGS=-Wall -g -O1
else
  DEBUGFLAGS=
  COMPILEFLAGS=-Wall -Werror -O3
endif

ccflags-y := $(COMPILEFLAGS) $(DEBUGFLAGS)

# Default rule to run make within the kernel environment
all:
	#@ KCFLAGS+="$(COMPILEFLAGS) $(DEBUGFLAGS)" make -C $(LINUX_HOME) M=$(PWD) modules
	@ make -C $(LINUX_HOME) M=$(PWD) modules
clean:
	@ make -C $(LINUX_HOME) M=$(PWD) clean

install: $(DRV_NAME).ko
	install -d $(INSTDIR)
	install -m 644 $(DRV_NAME).ko $(INSTDIR)
	depmod $(LNX)
