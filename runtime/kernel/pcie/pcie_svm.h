/*
* Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
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
#ifndef PCIE_SVM_H__
#define PCIE_SVM_H__

#include <linux/version.h>

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)

#include <linux/sort.h>
#include <linux/mmu_notifier.h>
#include <linux/migrate.h>
#include <linux/swap.h>
#include <linux/swapops.h>
#include <linux/sched/mm.h>
#include <linux/interval_tree.h>
#include <tlkm/tlkm_bus.h>
#include "pcie/pcie_device.h"
#include "pcie/pcie.h"

#define PHYS_MEM_SIZE (4UL << 30) // use standard 4 GB memory size

// IOMMU
#define MMU_DROP_FAULT 0x1UL
#define MMU_INVALIDATE_ENTRY 0x2UL
#define MMU_INVALIDATE_ALL 0x3UL
#define MMU_ADD_ENTRY 0x4UL
#define MMU_ADD_AL_ENTRY 0x6UL
#define MMU_ACTIVATE 0x8UL
#define MMU_DEACTIVATE 0x9UL

#define MMU_MAX_MAPPING_LENGTH 4096
#define MMU_AL_LENGTH_SHIFT 48UL

#define MMU_STATUS_MEM_ACCESS_ACTIVE (1UL)
#define MMU_STATUS_ANY_MEM_ACCESS (1UL << 1)
#define MMU_STATUS_INTR_ACTIVE (1UL << 2)

#define MMU_INTR_ENABLE (1UL)
#define MMU_ISSUE_FAULT_ENABLE (1UL << 1)

#define VALID_ADDR_FLAG (1UL << 63)
#define SECOND_TRY_FLAG (1UL << 62)
#define VADDR_MASK (0xFFFFFFFFFFFF)
#define MAX_NUM_FAULTS 32

// DMA
#define NETWORK_PAGE_DMA_ID 0x5A6ED4AE
#define MAC_PREFIX (0x005D03UL << 24)
#define PAGE_DMA_STAT_BUSY (1UL)
#define PAGE_DMA_STAT_INTR_PEND (1UL << 1)
#define PAGE_DMA_STAT_ERROR_FLAGS (3UL << 2)
#define PAGE_DMA_STAT_INTR_EN (1UL << 4)
#define PAGE_DMA_STAT_FIFO_FULL (1UL << 7)

#define PAGE_DMA_CTRL_RESET_INTR (1UL << 1)
#define PAGE_DMA_CTRL_INTR_ENABLE (1UL << 5)
#define PAGE_DMA_CTRL_INTR_DISABLE (1UL << 6)
#define PAGE_DMA_CMD_START (1UL << 63)
#define PAGE_DMA_CMD_CLEAR (1UL << 62)
#define PAGE_DMA_CMD_NETWORK (1UL << 60)

#define PAGE_DMA_MAX_NPAGES 4096UL
#define DEV_TO_DEV_DMA_MAX_NPAGES 1024

#define PAGE_FAULT_IRQ_NO 2
#define C2H_IRQ_NO 0
#define H2C_IRQ_NO 1

irqreturn_t iommu_page_fault_handler(int irq, void *data);
int pcie_init_svm(struct tlkm_pcie_device *pdev);
void pcie_exit_svm(struct tlkm_pcie_device *pdev);
int pcie_launch_svm(struct tlkm_device *inst);
void pcie_teardown_svm(struct tlkm_device *inst);
int pcie_svm_user_managed_migration_to_ram(struct tlkm_device *inst,
					   uint64_t vaddr, uint64_t size);
int pcie_svm_user_managed_migration_to_device(struct tlkm_device *inst,
					      uint64_t vaddr, uint64_t size);

/* struct to hold data related to SVM */
struct tlkm_pcie_svm_data {
	struct tlkm_pcie_device *pdev;
	struct task_struct *task;
	struct mm_struct *mm;
	struct svm_mmu_notifier_env *notifier_env;
	struct mmu_regs *mmu_regs;
	struct page_dma_regs *dma_regs;
	bool network_dma_enabled;
	uint64_t mac_addr;

	unsigned long base_pfn;
	struct list_head free_mem_blocks;
	struct mutex mem_block_mutex;
	struct rb_root_cached vmem_intervals;

	// work queues
	struct workqueue_struct *page_fault_queue;
	struct workqueue_struct *dev_mem_free_queue;

	// wait queues
	wait_queue_head_t wait_queue_h2c_intr;
	wait_queue_head_t wait_queue_c2h_intr;
	atomic_t wait_flag_h2c_intr;
	atomic_t wait_flag_c2h_intr;
};

/* envelope around MMU notifier */
struct svm_mmu_notifier_env {
	struct tlkm_pcie_svm_data *svm_data;
	struct mmu_notifier notifier;
};

/* control register map of TapascpMMU */
struct mmu_regs {
	uint64_t cmd;
	uint64_t vaddr;
	uint64_t paddr;
	uint64_t faulted_vaddr;
	uint64_t intr_enable;
	uint64_t status;
} __packed;

/* control register map of PageDMA core */
struct page_dma_regs {
	uint64_t c2h_status_ctrl;
	uint64_t c2h_src_addr;
	uint64_t c2h_dst_addr;
	uint64_t c2h_start_len;
	uint64_t h2c_status_ctrl;
	uint64_t h2c_src_addr;
	uint64_t h2c_dst_addr;
	uint64_t h2c_start_len;
	uint64_t id;
	uint64_t own_mac;
	uint64_t dst_mac;
};

/* envelope around work struct for IOMMU page fault handling */
struct page_fault_work_env {
	struct tlkm_pcie_device *pdev;
	struct work_struct work;
};

/* envelope around work struct for device memory free commands */
struct dev_mem_free_work_env {
	struct tlkm_pcie_device *pdev;
	struct work_struct work;
	uint64_t dev_addr;
	uint64_t size;
};

/* physical memory block for device memory allocator */
struct device_memory_block {
	struct list_head list;
	uint64_t base_addr;
	uint64_t size;
};

/* list entry for list of interval nodes */
struct vmem_interval_list_entry {
	struct list_head list;
	struct interval_tree_node *interval_node;
};

#endif /* defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */

#endif /* PCIE_SVM_H__ */