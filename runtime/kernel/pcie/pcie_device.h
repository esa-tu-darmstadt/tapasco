//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
#ifndef PCIE_DEVICE_H__
#define PCIE_DEVICE_H__

#include <linux/workqueue.h>
#include <linux/version.h>
#include "tlkm_types.h"
#include "platform_global.h"
#include "dma/tlkm_dma.h"

#define TLKM_PLATFORM_INTERRUPTS		4
#define TLKM_SLOT_INTERRUPTS			PLATFORM_NUM_SLOTS
#define REQUIRED_INTERRUPTS \
		(TLKM_PLATFORM_INTERRUPTS + TLKM_SLOT_INTERRUPTS)

uint32_t get_xdma_reg_addr(uint32_t target, uint32_t channel, uint32_t offset);

int  tlkm_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id);
void tlkm_pcie_remove(struct pci_dev *pdev);

int  pcie_device_create(struct tlkm_device *dev, void *data);
void pcie_device_destroy(struct tlkm_device *dev);
int  pcie_device_init_subsystems(struct tlkm_device *dev, void *data);
void pcie_device_exit_subsystems(struct tlkm_device *dev);

int pcie_device_dma_allocate_buffer(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size);
void pcie_device_dma_free_buffer(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size);

int pcie_device_dma_sync_buffer_cpu(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size);
int pcie_device_dma_sync_buffer_dev(dev_id_t dev_id, struct tlkm_device *dev, void** buffer, void **dev_handle, dma_direction_t direction, size_t size);

/* struct to hold data related to the pcie device */
struct tlkm_pcie_device {
	struct tlkm_device	*parent;
	struct pci_dev 		*pdev;
	u64 			phy_addr_bar0;
	u64 			phy_len_bar0;
	u64 			phy_flags_bar0;
	int 			irq_mapping[REQUIRED_INTERRUPTS];
	void 			*irq_data[REQUIRED_INTERRUPTS];
	int			link_width;
	int			link_speed;
	struct work_struct	irq_work[TLKM_SLOT_INTERRUPTS];
#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
	struct msix_entry 	msix_entries[REQUIRED_INTERRUPTS];
#endif
};

ssize_t pcie_enumerate(void);
ssize_t pcie_device_probe(struct tlkm_class *cls);

#if LINUX_VERSION_CODE < KERNEL_VERSION(4,8,0)
static inline
u32 pci_irq_vector(struct pci_dev *pdev, int c) {
	return ((struct tlkm_pcie_device *)dev_get_drvdata(&pdev->dev))->msix_entries[c].vector;
}
#endif

#endif // PCIE_DEVICE_H__
