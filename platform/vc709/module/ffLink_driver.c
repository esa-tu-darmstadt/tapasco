//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
//
// This file is part of Tapasco (TPC).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file ffLink_driver.c 
 * @brief Implementation of linux kernel driver module
	this is the global entry point for the operating system to (un-)load the driver
	afterwards the register routines of all submodules are called
	licensing of the module and short description is covered here as well
 * */

/******************************************************************************/

#include "ffLink_driver.h"

/******************************************************************************/
/* init and exit calls when driver is (un)loaded */

/**
 * @brief Device driver initialization code
	loads two char-device drivers for communication to user-registers
	and handling dma_transfers
	these char-devices communicate over pcie, which is loaded in the third part
 * @param none
 * @return Zero, if initialization was successfull
 * */
static int __init fflink_init(void) 
{
	int err = 0;
	
	fflink_notice("Init char-dev(s), dev-entries and register pci-device\n");
	
	err = char_dma_register();
	if(err) {
		fflink_info("Could not register dma char device(s)\n");
		goto error_dma_register;
	}
	
	err = char_user_register();
	if(err) {
		fflink_info("Could not register user char device(s)\n");
		goto error_user_register;
	}
	
	err = pcie_register();
	if(err) {
		fflink_info("Could not register pcie device\n");
		goto error_pcie_register;
	}
	
	fflink_warn("Successfully registered driver\n");
	
	return 0;
	
error_dma_register:
	return -EACCES;
error_user_register:
	char_dma_unregister();
	return -EACCES;
error_pcie_register:
	char_user_unregister();
	return -EACCES;
}

/**
 * @brief Device driver cleanup code
 * @param none
 * @return No return value, if failures happen here, module is stuck into the kernel
 * */
static void __exit fflink_exit(void)
{
	fflink_notice("Deallocate char-dev(s)/pci-device\n");
	
	char_dma_unregister();
	
	char_user_unregister();
	
	pcie_unregister();
	
	fflink_warn("Successfully unregistered driver\n");
}

/******************************************************************************/
/* module stuff for basic information and (un)loading driver */

/* standard license, driver and author information */
MODULE_LICENSE("GPL");
MODULE_AUTHOR("David de la Chevallerie");
MODULE_DESCRIPTION("Zero copy and bounce-/double-buffering driver for PCIe-FPGA communication.");
MODULE_VERSION(XSTRV(FFLINK_VERSION));

/* register init/exit methods called by insmod/rmmod */
module_init(fflink_init);
module_exit(fflink_exit);

/******************************************************************************/
