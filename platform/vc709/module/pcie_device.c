//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file pcie_device.c 
 * @brief Implementation of all the pcie-device related functions - the code will lookup the dev_id on the pcie-bus
	if a matching pcie-device is found, the pcie-device will probed and a basic configuration of the core is done
	expects the device to provide a bar0 register space, which will be used for access to its registers afterwards
	in addition up to 8 msi interrupts will be allocated for the char-devices of ffLink 
 * */

/******************************************************************************/

#include "pcie_device.h"

/******************************************************************************/
/* global variable declarations */

static struct pci_data_struct pci_data;

/******************************************************************************/

/**
 * @brief Enables pcie-device and claims/remaps neccessary bar resources
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_device(struct pci_dev *pdev)
{
	int err = 0;
	
	/* wake up the pci device */
	err = pci_enable_device(pdev);
	if(err) {
		fflink_warn("failed to enable pci device %d\n", err);
		goto error_pci_en;
	}
	
	/* set busmaster bit in config register */
	pci_set_master(pdev);
	
	/* Setup the BAR memory regions */
	err = pci_request_regions(pdev, FFLINK_PCI_NAME);
	if (err) {
		fflink_warn("failed to enable pci device %d\n", err);
		goto error_pci_req;
	}
		
	/* read out pci bar 0 settings */
	pci_data.pdev = pdev;
	pci_data.phy_addr_bar0 = pci_resource_start(pdev, 0);
	pci_data.phy_len_bar0 = pci_resource_len(pdev, 0);
	pci_data.phy_flags_bar0 = pci_resource_flags(pdev, 0);
	
	fflink_notice("PCI Bar 0 Settings - Address: %llx Length: %llx\n", pci_data.phy_addr_bar0, pci_data.phy_len_bar0);
	
	/* map physical address to kernel space */
	pci_data.kvirt_addr_bar0 = ioremap(pci_data.phy_addr_bar0, pci_data.phy_len_bar0);
	if (IS_ERR(pci_data.kvirt_addr_bar0)) {
		fflink_warn("Cannot remap Bar 0 address to kernel space\n");
		goto error_pci_remap;
	}
	fflink_info("Remapped Bar 0 Address is: %llx\n", (unsigned long long int) pci_data.kvirt_addr_bar0);
	
	return 0;

error_pci_remap:	
	pci_release_regions(pdev);
error_pci_req:
	pci_disable_device(pdev);
error_pci_en:
	return -ENODEV;
}

/**
 * @brief Configures pcie-device and bit_mask settings
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int configure_device(struct pci_dev *pdev)
{
	int err = 0;
	u16 ctrl_reg = 0;
	
	/* dma mask to set dma-able area
     * currently pci specific code, but could be implemented with dma-api directly */
	//err = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(DMA_MAX_BIT));
	err = pci_set_dma_mask(pdev, DMA_BIT_MASK(DMA_MAX_BIT));
	if(err) {
		fflink_warn("%u-bit area is not completly dma-able\n", DMA_MAX_BIT);
		goto error_pci_dma_mask;
	}
	err = pci_set_consistent_dma_mask(pdev, DMA_BIT_MASK(DMA_MAX_BIT));
	if(err) {
		fflink_warn("%u-bit area is not completly dma-able (consistent)\n", DMA_MAX_BIT);
		goto error_pci_dma_mask;
	}
	
	/* FIXME: Bytes hardcoded and could change with newer kernel versions
	 * set MPS to 256 Byte (0x20 for 256 or 0x60 for 512) */
	pcie_capability_read_word(pdev, PCI_EXP_DEVCTL, &ctrl_reg);
	fflink_info("Settings of PCI_EXP_DEVCTL: %X\n", ctrl_reg);
	pcie_capability_write_word(pdev, PCI_EXP_DEVCTL, ctrl_reg | 0x20);
	
	/* set RCB to maximum */
	pcie_capability_read_word(pdev, PCI_EXP_LNKCTL, &ctrl_reg);
	fflink_info("Settings of PCI_EXP_LNKCTL from pcie-device: %X\n", ctrl_reg);
	pcie_capability_write_word(pdev, PCI_EXP_LNKCTL, ctrl_reg | PCI_EXP_LNKCTL_RCB);
	
	return 0;
	
error_pci_dma_mask:
	return -EINVAL;
}

/**
 * @brief Register specific function with msi interrupt line
 * @param pdev Pointer to pci-device, which should be allocated
 * @param int interrupt number relative to global interrupt number
 * @return Returns error code or zero if success
 * */
static int register_intr_handler(struct pci_dev *pdev, int c)
{
	int err = 0;
	/* Request interrupt line for unique function
	 * alternatively function will be called from free_irq as well with flag IRQF_SHARED */
	switch(c) {
		case 0:
			err = request_irq(pdev->irq + c, intr_handler_dma_0, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 1:
			err = request_irq(pdev->irq + c, intr_handler_dma_1, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 2:
			err = request_irq(pdev->irq + c, intr_handler_dma_2, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 3:
			err = request_irq(pdev->irq + c, intr_handler_dma_3, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 4:
			err = request_irq(pdev->irq + c, intr_handler_user_0, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 5:
			err = request_irq(pdev->irq + c, intr_handler_user_1, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 6:
			err = request_irq(pdev->irq + c, intr_handler_user_2, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		case 7:
			err = request_irq(pdev->irq + c, intr_handler_user_3, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, &pci_data);
			fflink_notice("Interrupt Line %d assigned with return value %d\n", pdev->irq + c, err);
			pci_data.irq_assigned++;
			break;
		default:
			fflink_notice("No more interrupt handler for number (%d)\n", pdev->irq + c);
			break;
	}
	return err;
}

/**
 * @brief Initializes msi-capable structure and binds to irq_functions
 * @param pci_dev device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_msi(struct pci_dev *pdev)
{
	int err = 0, i;
	
	/* set up MSI interrupt vector to max size */
	fflink_info("Have %d MSI vectors\n", pci_msi_vec_count(pdev));
	err = pci_enable_msi_range(pdev, 1, pci_msi_vec_count(pdev));
	
	if (err <= 0) {
		fflink_warn("Cannot set MSI vector (%d)\n", err);
		goto error_no_msi;
	} else {
		fflink_info("Got %d MSI vectors starting at %d\n", err, pdev->irq);
	}
	pci_data.irq_first = pdev->irq;
	pci_data.irq_length = err;
	pci_data.irq_assigned = 0;
	
	for(i = 0; i < pci_data.irq_length; i++) {
		err = register_intr_handler(pdev, i);
		if (err) {
			fflink_warn("Cannot request Interrupt number %d\n", i);
			goto error_pci_req_irq;
		}
	}
	
	return 0;
	
error_pci_req_irq:
	for(i = i-1; i >= 0; i--)
		free_irq(pci_data.irq_first + i, &pci_data);
	pci_disable_msi(pci_data.pdev);
error_no_msi:
	return -ENOSPC;
}

/**
 * @brief Tell about link configuration
 * @param pdev Pointer to pci-device
 * @return none
 * */
static void report_link_status(struct pci_dev *pdev)
{
	u16 ctrl_reg = 0;
	
	pcie_capability_read_word(pdev, PCI_EXP_LNKSTA, &ctrl_reg);
	
	/* report current link settings */
	if((ctrl_reg & PCI_EXP_LNKSTA_NLW_X1) > 0)
		fflink_notice("Current Link Width x1\n");
	else if((ctrl_reg & PCI_EXP_LNKSTA_NLW_X2) > 0)
		fflink_notice("Current Link Width x2\n");
	else if((ctrl_reg & PCI_EXP_LNKSTA_NLW_X4) > 0)
		fflink_notice("Current Link Width x4\n");
	else if((ctrl_reg & PCI_EXP_LNKSTA_NLW_X8) > 0)
		fflink_notice("Current Link Width x8\n");
	else
		fflink_warn("Current Link Width error\n");
	
	if((ctrl_reg & PCI_EXP_LNKSTA_CLS_8_0GB) > 0)
		fflink_notice("Current Link Speed 8.0GT/s\n");
	else if((ctrl_reg & PCI_EXP_LNKSTA_CLS_5_0GB) > 0)
		fflink_notice("Current Link Speed 5.0GT/s\n");
	else if((ctrl_reg & PCI_EXP_LNKSTA_CLS_2_5GB) > 0)
		fflink_notice("Current Link Speed 2.5GT/s\n");
	else
		fflink_warn("Current Link Speed error\n");
}

/******************************************************************************/
/* helper functions externally called to ease access over pcie */

/**
 * @brief Get access to pcie-device mapping information
 * @param none
 * @return Returns pdev structure of pcie dev
 * */
struct pci_dev* get_pcie_dev(void)
{
	if(IS_ERR(pci_data.pdev))
		fflink_warn("PCIe dev not initialized\n");
		
	return pci_data.pdev;
}

/**
 * @brief Get access to pcie-device base address to access pcie register space
 * @param none
 * @return Returns kernel address of bar 0
 * */
void * get_virt_bar0_addr(void)
{
	if(IS_ERR(pci_data.kvirt_addr_bar0))
		fflink_warn("Bar 0 address not valid\n");
		
	return pci_data.kvirt_addr_bar0;
}

/**
 * @brief Write to register space to access axi_lite_slaves
 * 		  hides pcie specific details
 * @param data Data to write into register
 * @param addr Address corresponding to AXI Map
 * @return none
 * */
void pcie_writel(unsigned long data, void * addr)
{
	writel(data, pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

/**
 * @brief Read from register space to access axi_lite_slaves
 * 		  hides pcie specific details
 * @param addr Address corresponding to AXI Map
 * @return Data read from register
 * */
unsigned long pcie_readl(void * addr)
{
	return readl(pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

/******************************************************************************/
/* helper functions internally called to (un/)load this pcie device */

/**
 * @brief Called, when matching id table is found to initialize pcie device
 * @param pdev Pointer to pci-device, which should be allocated
 * @param id Pointer to ID entry matching - only one entry supported, so no need to check this again
 * @return Returns error code or zero if success
 * */
static int fflink_pci_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	fflink_info("Init pcie-dev for bus mastering\n");
	
	if(claim_device(pdev)) {
		goto error_no_device;
	}
	if(configure_device(pdev)) {
		goto error_cannot_configure;
	}
	if(claim_msi(pdev)) {
		goto error_cannot_configure;
	}
	
	report_link_status(pdev);
	
	return 0;
	
error_cannot_configure:
	iounmap(pci_data.kvirt_addr_bar0);
	pci_release_regions(pdev);
	pci_disable_device(pdev);
error_no_device:
	return -ENOSPC;
}

/**
 * @brief Called, when driver is unloaded to release pcie-device
 * @param pdev Pointer to pci-device, which should be deallocated
 * @return none
 * */
static void fflink_pci_remove(struct pci_dev *pdev)
{
	int i;
	fflink_info("Unload pci-device\n");
	
	for(i = 0; i < pci_data.irq_assigned; i++)
		free_irq(pci_data.irq_first + i, &pci_data);
	
	pci_disable_msi(pci_data.pdev);
	
	iounmap(pci_data.kvirt_addr_bar0);
	
	pci_release_regions(pdev);
	
	pci_disable_device(pdev);
}

/******************************************************************************/
/* helper functions externally called to (un/)load this pcie device */

/**
 * @brief Registers pcie-driver/interrupts and initializes capabilities
 * @param none
 * @return Returns error code or zero if success
 * */
int pcie_register(void)
{
	int err = 0;
	
	fflink_info("Try to register pcie driver\n");
	
	err = pci_register_driver(&fflink_pci_driver);
	if (err) {
		fflink_warn("no pcie device claimed");
		return err;
	}
	
	return 0;
}

/**
 * @brief Unregisters pcie-driver/interrupts, which was initialized with pcie_register before
 * @param none
 * @return none
 * */
void pcie_unregister(void)
{
	fflink_info("Tidy up\n");
	
	pci_unregister_driver(&fflink_pci_driver);
}

/******************************************************************************/
