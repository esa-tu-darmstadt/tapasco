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
 * @file pcie_device.c
 * @brief Implementation of all the pcie-device related functions - the code will lookup the dev_id on the pcie-bus
	if a matching pcie-device is found, the pcie-device will probed and a basic configuration of the core is done
	expects the device to provide a bar0 register space, which will be used for access to its registers afterwards
	in addition at least 8 msi interrupts will be allocated for the char-devices of ffLink
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
	if (err) {
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
	fflink_info("Remapped Bar 0 Address is: %llx\n", (unsigned long long int) pci_data.kvirt_addr_bar2);

	return 0;

error_pci_remap:
	pci_release_regions(pdev);
error_pci_req:
	pci_disable_device(pdev);
error_pci_en:
	pci_data.pdev = 0;
	return -ENODEV;
}

/**
 * @brief Configures pcie-device and bit_mask settings
 * @param pdev Pointer to pci-device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int configure_device(struct pci_dev *pdev)
{
	fflink_info("Settings of MPS: %d and Maximum Read Request %d\n", pcie_get_mps(pdev), pcie_get_readrq(pdev));

	if(!dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
        fflink_info("dma_set_mask: Using 64 bit dma addresses\n");
        dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(64));
    } else if(!dma_set_mask(&pdev->dev, DMA_BIT_MASK(32))) {
        fflink_info("dma_set_mask: Using 32 bit dma addresses\n");
        dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(32));
    } else {
            fflink_warn("No suitable dma available\n");
            goto mask_error;
    }

	return 0;

mask_error:
	return -ENODEV;
}
/**
 * @brief Register specific function with msi interrupt line
 * @param pdev Pointer to pci-device, which should be allocated
 * @param int interrupt number relative to global interrupt number
 * @return Returns error code or zero if success
 * */
static int register_intr_handler(struct pci_dev *pdev, int c)
{
	int err = -1;
	/* Request interrupt line for unique function
	 * alternatively function will be called from free_irq as well with flag IRQF_SHARED */
	if (c == 0) {

		err = request_irq(pci_irq_vector(pdev, c), intr_handler_dma, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev);
	}

	if (c == 1 || c == 2 || c == 3) err = -2;

	if (c >= 4) {
		err = request_irq(pci_irq_vector(pdev, c), intr_handler_user, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev);
	}

	// Save the c to irq mapping for later use
	if (!err) {
		pci_data.irq_mapping[c] = pci_irq_vector(pdev, c);
		fflink_notice("Created mapping between interrupt %d and %d", c, pci_data.irq_mapping[c]);
		fflink_notice("Interrupt Line %d/%d assigned with return value %d\n", c, pci_irq_vector(pdev, c), err);
	}
	return err;
}

static int free_irqs(struct pci_dev *pdev)
{
	int i;

	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		if (pci_data.irq_mapping[i] != -1) {
			fflink_notice("Freeing interrupt %d with mapping %d", i, pci_data.irq_mapping[i]);
			free_irq(pci_data.irq_mapping[i], pdev);
			pci_data.irq_mapping[i] = -1;
		}
	}
	return 0;
}

int pcie_translate_irq_number(int irq) {
	int i;
	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		if (pci_data.irq_mapping[i] == irq) {
			return i;
		}
	}
	return -1;
}

/**
 * @brief Initializes msi-capable structure and binds to irq_functions
 * @param pci_dev device, which should be allocated
 * @return Returns error code or zero if success
 * */
static int claim_msi(struct pci_dev *pdev)
{
	int err = 0, i;

	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		pci_data.irq_mapping[i] = -1;
	}

	/* set up MSI interrupt vector to max size */
	err = pci_alloc_irq_vectors(pdev, REQUIRED_INTERRUPTS, REQUIRED_INTERRUPTS, PCI_IRQ_MSIX);

	if (err <= 0) {
		fflink_warn("Cannot set MSI vector (%d)\n", err);
		goto error_no_msi;
	} else {
		fflink_warn("Got %d MSI vectors\n", err);
	}

	for (i = 0; i < REQUIRED_INTERRUPTS; i++) {
		err = register_intr_handler(pdev, i);
		if (err == -2) fflink_warn("Interrupt number %d unused\n", i);
		else if (err) {

			fflink_warn("Cannot request Interrupt number %d\n", i);
			goto error_pci_req_irq;
		}
	}

	return 0;

error_pci_req_irq:
	free_irqs(pdev);
	pci_free_irq_vectors(pdev);
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
	if ((ctrl_reg & PCI_EXP_LNKSTA_NLW_X1) > 0)
		fflink_notice("Current Link Width x1\n");
	else if ((ctrl_reg & PCI_EXP_LNKSTA_NLW_X2) > 0)
		fflink_notice("Current Link Width x2\n");
	else if ((ctrl_reg & PCI_EXP_LNKSTA_NLW_X4) > 0)
		fflink_notice("Current Link Width x4\n");
	else if ((ctrl_reg & PCI_EXP_LNKSTA_NLW_X8) > 0)
		fflink_notice("Current Link Width x8\n");
	else
		fflink_warn("Current Link Width error\n");

	if ((ctrl_reg & PCI_EXP_LNKSTA_CLS_8_0GB) > 0)
		fflink_notice("Current Link Speed 8.0GT/s\n");
	else if ((ctrl_reg & PCI_EXP_LNKSTA_CLS_5_0GB) > 0)
		fflink_notice("Current Link Speed 5.0GT/s\n");
	else if ((ctrl_reg & PCI_EXP_LNKSTA_CLS_2_5GB) > 0)
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
	if (IS_ERR(pci_data.pdev))
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
	if (IS_ERR(pci_data.kvirt_addr_bar0))
		fflink_warn("Bar 0 address not valid\n");

	return pci_data.kvirt_addr_bar0;
}

/**
 * @brief Write to register space to access axi_lite_slaves
 * 	  hides pcie specific details
 * @param data Data to write into register
 * @param addr Address corresponding to AXI Map
 * @return none
 * */
void pcie_writel(unsigned long data, void * addr)
{
	if (pci_data.phy_len_bar0 <=  (long unsigned)addr) {
		fflink_warn("Illegal write request to address 0x%lx\n", (long unsigned)addr);
		return;
	}
	writel(data, pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

void pcie_writeq(unsigned long long data, void * addr)
{
	if (pci_data.phy_len_bar0 <=  (long unsigned)addr) {
		fflink_warn("Illegal write request to address 0x%lx\n", (long unsigned)addr);
		return;
	}
	writeq(data, pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

void pcie_writel_bar2(unsigned long data, void * addr)
{
	writel(data, pci_data.kvirt_addr_bar2 + (unsigned long long) addr);
}

/**
 * @brief Read from register space to access axi_lite_slaves
 * 		  hides pcie specific details
 * @param addr Address corresponding to AXI Map
 * @return Data read from register
 * */
unsigned long pcie_readl(void * addr)
{
	if (pci_data.phy_len_bar0 <= (long unsigned)addr) {
		fflink_warn("Illegal read request to address 0x%lx\n", (long unsigned)addr);
		return 0;
	}
	return readl(pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

unsigned long long pcie_readq(void * addr)
{
	if (pci_data.phy_len_bar0 <= (long unsigned)addr) {
		fflink_warn("Illegal read request to address 0x%lx\n", (long unsigned)addr);
		return 0;
	}
	return readq(pci_data.kvirt_addr_bar0 + (unsigned long long) addr);
}

unsigned long pcie_readl_bar2(void * addr)
{
	return readl(pci_data.kvirt_addr_bar2 + (unsigned long long) addr);
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

	if (claim_device(pdev)) {
		goto error_no_device;
	}
	if (configure_device(pdev)) {
		goto error_cannot_configure;
	}
	if (claim_msi(pdev)) {
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
	fflink_info("Unload pci-device\n");

	free_irqs(pdev);
	pci_free_irq_vectors(pdev);

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
