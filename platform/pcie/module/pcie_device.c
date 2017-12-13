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

#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
static struct msix_entry msix_entries[REQUIRED_INTERRUPTS];

u32 pci_irq_vector(struct pci_dev *pdev, int c) {
	return msix_entries[c].vector;
}

#endif

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

	if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(64))) {
		fflink_info("dma_set_mask: Using 64 bit dma addresses\n");
		dma_set_coherent_mask(&pdev->dev, DMA_BIT_MASK(64));
	} else if (!dma_set_mask(&pdev->dev, DMA_BIT_MASK(32))) {
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
		err = request_irq(pci_irq_vector(pdev, c), intr_handler_dma_read, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev);
	} else if (c == 1) {
		err = request_irq(pci_irq_vector(pdev, c), intr_handler_dma_write, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev);
	}

	if (c == 2 || c == 3) err = -2;

	switch (c) {
	case 4: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_0, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 5: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_1, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 6: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_2, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 7: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_3, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 8: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_4, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 9: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_5, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 10: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_6, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 11: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_7, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 12: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_8, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 13: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_9, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 14: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_10, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 15: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_11, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 16: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_12, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 17: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_13, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 18: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_14, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 19: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_15, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 20: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_16, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 21: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_17, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 22: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_18, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 23: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_19, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 24: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_20, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 25: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_21, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 26: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_22, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 27: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_23, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 28: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_24, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 29: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_25, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 30: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_26, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 31: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_27, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 32: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_28, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 33: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_29, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 34: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_30, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 35: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_31, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 36: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_32, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 37: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_33, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 38: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_34, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 39: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_35, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 40: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_36, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 41: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_37, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 42: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_38, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 43: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_39, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 44: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_40, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 45: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_41, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 46: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_42, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 47: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_43, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 48: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_44, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 49: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_45, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 50: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_46, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 51: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_47, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 52: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_48, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 53: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_49, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 54: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_50, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 55: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_51, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 56: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_52, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 57: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_53, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 58: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_54, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 59: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_55, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 60: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_56, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 61: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_57, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 62: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_58, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 63: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_59, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 64: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_60, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 65: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_61, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 66: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_62, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 67: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_63, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 68: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_64, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 69: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_65, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 70: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_66, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 71: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_67, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 72: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_68, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 73: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_69, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 74: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_70, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 75: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_71, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 76: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_72, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 77: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_73, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 78: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_74, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 79: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_75, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 80: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_76, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 81: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_77, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 82: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_78, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 83: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_79, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 84: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_80, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 85: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_81, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 86: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_82, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 87: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_83, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 88: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_84, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 89: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_85, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 90: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_86, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 91: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_87, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 92: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_88, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 93: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_89, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 94: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_90, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 95: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_91, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 96: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_92, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 97: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_93, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 98: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_94, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 99: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_95, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 100: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_96, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 101: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_97, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 102: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_98, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 103: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_99, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 104: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_100, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 105: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_101, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 106: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_102, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 107: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_103, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 108: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_104, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 109: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_105, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 110: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_106, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 111: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_107, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 112: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_108, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 113: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_109, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 114: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_110, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 115: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_111, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 116: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_112, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 117: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_113, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 118: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_114, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 119: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_115, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 120: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_116, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 121: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_117, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 122: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_118, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 123: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_119, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 124: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_120, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 125: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_121, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 126: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_122, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 127: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_123, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 128: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_124, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 129: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_125, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 130: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_126, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
	case 131: err = request_irq(pci_irq_vector(pdev, c), intr_handler_user_127, IRQF_EARLY_RESUME, FFLINK_PCI_NAME, pdev); break;
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
		#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
		msix_entries[i].entry = i;
		#endif
	}

	#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	err = pci_enable_msix_range(pdev, msix_entries, REQUIRED_INTERRUPTS, REQUIRED_INTERRUPTS);
	#else
	/* set up MSI interrupt vector to max size */
	err = pci_alloc_irq_vectors(pdev, REQUIRED_INTERRUPTS, REQUIRED_INTERRUPTS, PCI_IRQ_MSIX);
	#endif

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
	#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	pci_disable_msix(pdev);
	#else
	pci_free_irq_vectors(pdev);
	#endif
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
	#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	pci_disable_msix(pdev);
	#else
	pci_free_irq_vectors(pdev);
	#endif

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
