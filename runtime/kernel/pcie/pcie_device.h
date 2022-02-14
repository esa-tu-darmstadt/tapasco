/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef PCIE_DEVICE_H__
#define PCIE_DEVICE_H__

#include <linux/workqueue.h>
#include <linux/version.h>
#include "tlkm_types.h"
#include "dma/tlkm_dma.h"
#include "pcie/pcie_irq.h"
#include "pcie/pcie_irq_aws.h"
#include "zynq/zynq_irq.h"

#define TLKM_PCIE_NUM_DMA_BUFFERS 32

uint32_t get_xdma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset);

int tlkm_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id);
void tlkm_pcie_remove(struct pci_dev *pdev);

int pcie_device_create(struct tlkm_device *dev, void *data);
void pcie_device_destroy(struct tlkm_device *dev);
int pcie_device_init_subsystems(struct tlkm_device *dev, void *data);
void pcie_device_exit_subsystems(struct tlkm_device *dev);

int pcie_device_dma_allocate_buffer(dev_id_t dev_id, struct tlkm_device *dev,
				    void **buffer, dma_addr_t *dev_handle,
				    dma_direction_t direction, size_t size);
void pcie_device_dma_free_buffer(dev_id_t dev_id, struct tlkm_device *dev,
				 void **buffer, dma_addr_t *dev_handle,
				 dma_direction_t direction, size_t size);

int pcie_device_dma_sync_buffer_cpu(dev_id_t dev_id, struct tlkm_device *dev,
				    void **buffer, dma_addr_t *dev_handle,
				    dma_direction_t direction, size_t size);
int pcie_device_dma_sync_buffer_dev(dev_id_t dev_id, struct tlkm_device *dev,
				    void **buffer, dma_addr_t *dev_handle,
				    dma_direction_t direction, size_t size);

void pcie_device_miscdev_close(struct tlkm_device *dev);

inline void *pcie_device_addr2map_off(struct tlkm_device *dev,
				      dev_addr_t const addr);

struct dma_buf {
	void *ptr;
	dma_addr_t ptr_dev;
	size_t size;
	dma_direction_t direction;
};

/* struct to hold data related to the pcie device */
struct tlkm_pcie_device {
	struct tlkm_device *parent;
	struct pci_dev *pdev;
	u64 phy_addr_bar0;
	u64 phy_len_bar0;
	u64 phy_flags_bar0;
	int link_width;
	int link_speed;
	struct dma_buf dma_buffer[TLKM_PCIE_NUM_DMA_BUFFERS];
	volatile uint32_t *ack_register;
	volatile uint32_t *ack_register_aws;
	struct list_head *interrupts;
	struct zynq_irq_mapping intc_bases[AWS_NUM_IRQ_CONTROLLERS];
	int requested_irq_num;
#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)
	struct tlkm_pcie_svm_data *svm_data;
#endif
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
	struct msix_entry *msix_entries;
#endif
};

ssize_t pcie_enumerate(void);
ssize_t pcie_device_probe(struct tlkm_class *cls);

#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 8, 0)
static inline u32 pci_irq_vector(struct pci_dev *pdev, int c)
{
	return ((struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev))
		->msix_entries[c]
		.vector;
}
#endif

#endif // PCIE_DEVICE_H__
