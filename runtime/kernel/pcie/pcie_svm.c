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

#include "pcie/pcie_svm.h"

#if defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0)

/**
 * translate device address to corresponding PFN
 *
 * @param svm_data SVM data struct
 * @param dev_addr device address to translate
 * @return PFN corresponding to given device address
 */
static inline unsigned long
dev_addr_to_pfn(struct tlkm_pcie_svm_data *svm_data, uint64_t dev_addr)
{
	return ((dev_addr >> PAGE_SHIFT) + svm_data->base_pfn);
}

/**
 * translate PFN to corresponding device address
 *
 * @param svm_data SVM data struct
 * @param pfn PFN to translate
 * @return device address corresponding to given PFN
 */
static inline uint64_t
pfn_to_dev_addr(struct tlkm_pcie_svm_data *svm_data, unsigned long pfn)
{
	return ((pfn - svm_data->base_pfn) << PAGE_SHIFT);
}

/**
 * Initiate a card-to-host (C2H) DMA transfer using the PageDMA core
 *
 * @param svm_data SVM data struct
 * @param host_addr DMA address in host memory (destination address)
 * @param dev_addr address in device memory (source address)
 * @param npages number of pages to transfer
 * @param network if set transmit data over network connection
 */
static void
init_c2h_dma(struct tlkm_pcie_svm_data *svm_data, dma_addr_t host_addr,
	     uint64_t dev_addr, int npages, bool network)
{
	uint64_t npages_cmd, wval;
	struct page_dma_regs *dma_regs = svm_data->dma_regs;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "initiate C2H DMA: host addr = %llx, device addr = %llx, length = %0d, network = %0d",
	       host_addr, dev_addr, npages, network);

	while (npages) {
		writeq(dev_addr, &dma_regs->c2h_src_addr);
		if (!network)
			writeq(host_addr, &dma_regs->c2h_dst_addr);
		npages_cmd = (npages > PAGE_DMA_MAX_NPAGES) ?
				     PAGE_DMA_MAX_NPAGES :
					   npages;
		wval = npages_cmd | PAGE_DMA_CMD_START;
		if (network)
			wval |= PAGE_DMA_CMD_NETWORK;
		writeq(wval, &dma_regs->c2h_start_len);
		npages -= npages_cmd;
	}
}

/**
 * Initiate host-to-card (H2C) transfer using the PageDMA core
 *
 * @param svm_data SVM data struct
 * @param host_addr DMA address in host memory (source address)
 * @param dev_addr address in device memory (destination address)
 * @param pages number of pages to transfer
 * @param clear if set clear destination pages instead of copying data
 * @param network if set receive data over network connection
 */
static void
init_h2c_dma(struct tlkm_pcie_svm_data *svm_data, dma_addr_t host_addr,
	     uint64_t dev_addr, int npages, bool clear, bool network)
{
	uint64_t npages_cmd, wval;
	struct page_dma_regs *dma_regs = svm_data->dma_regs;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "initiate H2C DMA: host addr = %llx, device addr = %llx, length = %0d, clear = %0d, network = %0d",
	       host_addr, dev_addr, npages, clear, network);

	while (npages) {
		npages_cmd = (npages > PAGE_DMA_MAX_NPAGES) ?
				     PAGE_DMA_MAX_NPAGES :
					   npages;
		wval = npages_cmd | PAGE_DMA_CMD_START;
		if (clear)
			wval |= PAGE_DMA_CMD_CLEAR;
		if (network)
			wval |= PAGE_DMA_CMD_NETWORK;
		if (!network && !clear)
			writeq(host_addr, &dma_regs->h2c_src_addr);
		writeq(dev_addr, &dma_regs->h2c_dst_addr);

		writeq(wval, &dma_regs->h2c_start_len);
		npages -= npages_cmd;
	}
}

/**
 * Add a TLB entry to the on-FPGA IOMMU
 *
 * @param svm_data SVM data struct
 * @param vaddr virtual address of the new entry
 * @param paddr physical address of the new entry
 */
static inline void add_tlb_entry(struct tlkm_pcie_svm_data *svm_data,
				 uint64_t vaddr, uint64_t paddr)
{
	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "add TLB entry: vaddr = %llx, paddr = %llx", vaddr, paddr);
	writeq(vaddr, &svm_data->mmu_regs->vaddr);
	writeq(paddr, &svm_data->mmu_regs->paddr);
	writeq(MMU_ADD_ENTRY, &svm_data->mmu_regs->cmd);
}

/**
 * Add aan entry to the TLB with flexible length entries of the on-FPGA IOMMU
 *
 * @param svm_data SVM data struct
 * @param vaddr virtual base address of the new entry
 * @param paddr physical base address of the new entry
 * @param npages length of the new entry in pages
 */
static inline void add_al_tlb_entry(struct tlkm_pcie_svm_data *svm_data,
				    uint64_t vaddr, uint64_t paddr, int npages)
{
	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "add flexible length TLB entry: vaddr = %llx, paddr = %llx, length = %0d",
	       vaddr, paddr, npages);
	writeq(vaddr, &svm_data->mmu_regs->vaddr);
	writeq(paddr, &svm_data->mmu_regs->paddr);
	writeq(MMU_ADD_AL_ENTRY |
		       ((unsigned long)npages << MMU_AL_LENGTH_SHIFT),
	       &svm_data->mmu_regs->cmd);
}

/**
 * invalidate a TLB entry of the on-FPGA IOMMU
 *
 * @param svm_data SVM data struct
 * @param vaddr virtual address of entry to invalidate
 */
static inline void
invalidate_tlb_entry(struct tlkm_pcie_svm_data *svm_data, uint64_t vaddr)
{
	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "invalidate TLB entry: vaddr = %llx", vaddr);
	writeq(vaddr, &svm_data->mmu_regs->vaddr);
	writeq(MMU_INVALIDATE_ENTRY, &svm_data->mmu_regs->cmd);
}

/**
 * invalidate all TLB entries of the on-FPGA IOMMU in a virtual address range
 * @param svm_data SVM data struct
 * @param base virtual base address of address range to invalidate
 * @param npages length of address region to invalidate in pages
 */
static void
invalidate_tlb_range(struct tlkm_pcie_svm_data *svm_data, uint64_t base,
		     int npages)
{
	int i;
	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "invalidate TLB range: vaddr = %llx, length = %0d", base,
	       npages);
	for (i = 0; i < npages; ++i)
		invalidate_tlb_entry(svm_data, base + i * PAGE_SIZE);
}

/**
 * Drop a page fault to signal the on-FPGA IOMMU that it could not be resolved
 *
 * @param svm_data SVM data struct
 * @param vaddr virtual address of not resolved page fault
 */
static inline void drop_page_fault(struct tlkm_pcie_svm_data *svm_data,
				   uint64_t vaddr)
{
	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "drop page fault: vaddr = %llx", vaddr);
	writeq(vaddr, &svm_data->mmu_regs->vaddr);
	writeq(MMU_DROP_FAULT, &svm_data->mmu_regs->cmd);
}

/**
 * Insert a virtual memory region into the device's interval tree. It is merged
 * if preceeding/succeeding intervals exist.
 *
 * @param svm_data PCIe SVM data struct
 * @param vaddr base address of new interval
 * @param npages size of new interval in pages
 * @return SUCCESS - 0, FAILURE - error code
 */
static int
insert_vmem_interval(struct tlkm_pcie_svm_data *svm_data, uint64_t vaddr,
		     int npages)
{
	struct interval_tree_node *predecessor = NULL, *successor = NULL, *new;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "insert vmem interval at 0x%0llx with %0d pages", vaddr, npages);

	new = kmalloc(sizeof(*new), GFP_KERNEL);
	if (!new) {
		DEVERR(svm_data->pdev->parent->dev_id,
		       "failed to allocate memory for vmem interval entry");
		return -ENOMEM;
	}

	// check for preceding and succeeding interval
	if (vaddr > 0) {
		predecessor = interval_tree_iter_first(
			&svm_data->vmem_intervals, vaddr - PAGE_SIZE,
			vaddr - 1);
	}
	// TODO use interval_tree_iter_next if we found a predecessor previously for higher efficiency?
	successor = interval_tree_iter_first(&svm_data->vmem_intervals,
					     vaddr + npages * PAGE_SIZE,
					     vaddr + npages * PAGE_SIZE);

	if (predecessor) {
		new->start = predecessor->start;
		interval_tree_remove(predecessor, &svm_data->vmem_intervals);
		kfree(predecessor);
	} else {
		new->start = vaddr;
	}

	if (successor) {
		new->last = successor->last;
		interval_tree_remove(successor, &svm_data->vmem_intervals);
		kfree(successor);
	} else {
		new->last = vaddr + npages * PAGE_SIZE - 1;
	}

	interval_tree_insert(new, &svm_data->vmem_intervals);

	return 0;
}

/**
 * Remove virtual memory interval from device's interval tree. All intervals
 * falling in this region are removed. If the an existing interval exceeds the
 * interval to be removed, it is split and re-inserted with the remaining bounds.
 *
 * @param svm_data PCIe SVM data struct
 * @param vaddr base address of interval to remove
 * @param npages size of interval to remove in pages
 */
static void
remove_vmem_interval(struct tlkm_pcie_svm_data *svm_data, uint64_t vaddr,
		     int npages)
{
	unsigned long start, next_start, end;
	struct interval_tree_node *node, *next_node, *new;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "remove vmem interval at 0x%0llx with %0d pages", vaddr, npages);

	start = vaddr;
	end = vaddr + npages * PAGE_SIZE - 1;
	node = interval_tree_iter_first(&svm_data->vmem_intervals, vaddr, end);
	while (node) {
		next_start = min(node->last + 1, end);
		next_node = interval_tree_iter_next(node, start, end);

		interval_tree_remove(node, &svm_data->vmem_intervals);

		// if node must not be removed completely, update and re-insert
		if (node->start != start) {
			if (node->last > end) {
				new = kmalloc(sizeof(*new), GFP_KERNEL);
				if (!new) {
					DEVERR(svm_data->pdev->parent->dev_id,
					       "failed to allocate memory for new interval entry");
				} else {
					new->start = end + 1;
					new->last = node->last;
					interval_tree_insert(new,
							     &svm_data->vmem_intervals);
				}
			}
			node->last = start - 1;
			interval_tree_insert(node, &svm_data->vmem_intervals);
		} else if (node->last > end) {
			node->start = end + 1;
			interval_tree_insert(node, &svm_data->vmem_intervals);
		} else {
			kfree(node);
		}

		start = next_start;
		node = next_node;
	}
}

/**
 * Find all overlapping virtual memory intervals in a device's interval tree.
 *
 * @param svm_data PCIe SVM data struct
 * @param interval_list head of list for all found intervals
 * @param vaddr base address of interval to search
 * @param npages size of interval to search in pages
 * @return SUCCESS - 0, FAILURE - error code
 */
static int search_vmem_intervals(struct tlkm_pcie_svm_data *svm_data,
				 struct list_head *interval_list,
				 uint64_t vaddr, int npages)
{
	unsigned long start, end;
	struct interval_tree_node *node;
	struct vmem_interval_list_entry *entry;

	end = vaddr + npages * PAGE_SIZE - 1;
	node = interval_tree_iter_first(&svm_data->vmem_intervals, vaddr, end);
	while (node) {
		entry = kmalloc(sizeof(*entry), GFP_KERNEL);
		if (!entry) {
			DEVERR(svm_data->pdev->parent->dev_id,
			       "failed to allocate memory for list entry");
			return -ENOMEM;
		}
		entry->interval_node = node;
		list_add_tail(&entry->list, interval_list);

		start = min(node->last + 1, end);
		node = interval_tree_iter_next(node, start, end);
	}
	return 0;
}

/**
 * Return whether the page for a given virtual address is present on the device.
 */
static inline bool
is_page_present(struct tlkm_pcie_svm_data *svm_data, uint64_t vaddr)
{
	if (interval_tree_iter_first(&svm_data->vmem_intervals, vaddr,
				     vaddr + PAGE_SIZE - 1))
		return true;
	return false;
}

/**
 * Allocate a region in device memory
 *
 * @param svm_data SVM data struct
 * @param size size of requested memory region
 * @return physical base address of allocated memory region, or -1 in case of failure
 */
static uint64_t allocate_device_memory(struct tlkm_pcie_svm_data *svm_data,
				       uint64_t size)
{
	uint64_t addr;
	struct device_memory_block *mem_block;

	mutex_lock(&svm_data->mem_block_mutex);
	if (list_empty(&svm_data->free_mem_blocks)) {
		DEVERR(svm_data->pdev->parent->dev_id,
		       "no more free memory segments available");
		addr = -1;
		goto skip_search;
	}
	mem_block = list_first_entry(&svm_data->free_mem_blocks,
				     typeof(*mem_block), list);
	while (1) {
		if (mem_block->size >= size) {
			addr = mem_block->base_addr;
			mem_block->size -= size;
			if (mem_block->size) {
				mem_block->base_addr += size;
			} else {
				list_del(&mem_block->list);
				kfree(mem_block);
			}
			break;
		}
		if (list_is_last(&mem_block->list,
				 &svm_data->free_mem_blocks)) {
			DEVERR(svm_data->pdev->parent->dev_id,
			       "no matching free memory segment available");
			addr = -1;
			break;
		} else {
			mem_block = list_next_entry(mem_block, list);
		}
	}

skip_search:
	mutex_unlock(&svm_data->mem_block_mutex);

	if (addr != -1)
		DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
		       "allocated device memory segment: addr = %llx, size = %llx",
		       addr, size);

	return addr;
}

/**
 * create a new list entry for the list of free memory blocks in device memory
 *
 * @param dev_addr base address of the new entry
 * @param size size of the new entry in bytes
 * @return pointer to created list entry
 */
static inline struct device_memory_block *
create_mem_block_entry(uint64_t dev_addr, uint64_t size)
{
	struct device_memory_block *mem_block =
		kmalloc(sizeof(*mem_block), GFP_KERNEL);
	if (!mem_block)
		return NULL;
	mem_block->base_addr = dev_addr;
	mem_block->size = size;
	return mem_block;
}

/**
 * free a memory region in device memory
 *
 * @param svm_data SVM data struct
 * @param dev_addr base address of the memory region
 * @param size size of the memory region
 */
static void free_device_memory(struct tlkm_pcie_svm_data *svm_data,
			       uint64_t dev_addr, uint64_t size)
{
	struct device_memory_block *mem_block, *prev_mem_block, *new_mem_block;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "free memory block: paddr = %llx, size = %llx", dev_addr, size);

	mutex_lock(&svm_data->mem_block_mutex);
	if (list_empty(&svm_data->free_mem_blocks)) {
		// list is empty, add freed memory as new block
		new_mem_block = create_mem_block_entry(dev_addr, size);
		if (!new_mem_block)
			DEVERR(svm_data->pdev->parent->dev_id,
			       "failed to allocate memory for new mem block entry");
		else
			list_add(&new_mem_block->list,
				 &svm_data->free_mem_blocks);
		goto unlock;
	}

	prev_mem_block = NULL;
	mem_block = list_first_entry(&svm_data->free_mem_blocks,
				     typeof(*mem_block), list);
	while (1) {
		// add freed block before current block
		// check whether it can be merged directly with previous
		// or current block
		if (mem_block->base_addr > dev_addr) {
			if (prev_mem_block &&
			    prev_mem_block->base_addr + prev_mem_block->size ==
				    dev_addr) {
				if (dev_addr + size == mem_block->base_addr) {
					// merge previous and next memory block to
					// one large block including freed section
					prev_mem_block->size +=
						size + mem_block->size;
					list_del(&mem_block->list);
					kfree(mem_block);
				} else {
					prev_mem_block->size += size;
				}
			} else if (dev_addr + size == mem_block->base_addr) {
				mem_block->base_addr = dev_addr;
				mem_block->size += size;
			} else {
				new_mem_block =
					create_mem_block_entry(dev_addr, size);
				if (!new_mem_block)
					DEVERR(svm_data->pdev->parent->dev_id,
					       "failed to allocate memory for new mem block entry");
				else
					list_add_tail(&new_mem_block->list,
						      &mem_block->list);
			}
			break;
		}

		// current block is the last in the list so merge or add the
		// freed block with/behind it
		if (list_is_last(&mem_block->list,
				 &svm_data->free_mem_blocks)) {
			if (mem_block->base_addr + mem_block->size ==
			    dev_addr) {
				mem_block->size += size;
			} else {
				new_mem_block =
					create_mem_block_entry(dev_addr, size);
				if (!new_mem_block)
					DEVERR(svm_data->pdev->parent->dev_id,
					       "failed to allocate memory for new mem block entry");
				else
					list_add(&new_mem_block->list,
						 &mem_block->list);
			}
			break;
		}

		// continue search
		prev_mem_block = mem_block;
		mem_block = list_next_entry(mem_block, list);
	}
unlock:
	mutex_unlock(&svm_data->mem_block_mutex);
}

/**
 * Free a memory region of device memory.
 *
 * @param work work struct containing address and size of the memory region to be freed
 */
static void handle_device_memory_free(struct work_struct *work)
{
	struct dev_mem_free_work_env *env =
		container_of(work, typeof(*env), work);

	free_device_memory(env->pdev->svm_data, env->dev_addr, env->size);
	kfree(env);
}

/**
 * Enqueue a new work struct to the workqueue handling device memory freeing
 *
 * @param pdev TLKM PCIe device struct
 * @param svm_data SVM data struct
 * @param dev_addr base address of the memory region to be freed
 * @param size size of the memory region to be freed
 * @return true if work could be enqueued, false otherwise
 */
static inline int queue_dev_mem_free_work(struct tlkm_pcie_device *pdev,
					  uint64_t dev_addr, uint64_t size)
{
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	struct dev_mem_free_work_env *env = kmalloc(sizeof(*env), GFP_KERNEL);
	if (!env) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate memory for work struct");
		return false;
	}
	env->pdev = pdev;
	env->dev_addr = dev_addr;
	env->size = size;
	INIT_WORK(&env->work, handle_device_memory_free);
	return queue_work(svm_data->dev_mem_free_queue, &env->work);
}


/**
 * Free a device page and the corresponding device memory
 *
 * @param pdev TLKM PCIe device struct
 * @param page page to free
 */
static inline void
free_device_page(struct tlkm_pcie_device *pdev, struct page *page)
{
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	if (page->zone_device_data) {
		if (!queue_dev_mem_free_work(pdev, pfn_to_dev_addr(svm_data,
								   page_to_pfn(
									   page)),
					     PAGE_SIZE))
			DEVERR(pdev->parent->dev_id,
			       "failed to queue work struct for freeing device memory region");
	}
}

/**
 * Free a device page and the corresponding memory allocation. This function
 * is only called by the OS kernel.
 *
 * @param page page to free
 */
static void kernel_page_free(struct page *page)
{
	struct tlkm_pcie_device *pdev = page->pgmap->owner;
	free_device_page(pdev, page);
}

/**
 * Migrate one page from device to host memory. This function is only called by
 * the OS after a CPU page fault on a migrated page.
 *
 * @param vmf VM fault struct containing the page to be migrated
 * @return Zero when succeeding, VM_FAULT_SIGBUS in case of failure
 */
static vm_fault_t svm_migrate_to_ram(struct vm_fault *vmf)
{
	unsigned long src = 0, dst = 0;
	dma_addr_t dma_addr;
	uint64_t src_addr, rval;
	struct migrate_vma migrate;
	struct page *src_page, *dst_page;

	struct tlkm_pcie_device *pdev = vmf->page->pgmap->owner;
	struct pci_dev *pci_dev = pdev->pdev;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "handle CPU page fault: vaddr = %lx", vmf->address);

	// invalidate TLB entry and check for active access
	invalidate_tlb_entry(svm_data, vmf->address);
	while (readq(&svm_data->mmu_regs->status) &
	       MMU_STATUS_MEM_ACCESS_ACTIVE);

	// populate migrate_vma struct and setup migration
	migrate.vma = vmf->vma;
	migrate.dst = &dst;
	migrate.src = &src;
	migrate.start = vmf->address;
	migrate.end = vmf->address + PAGE_SIZE;
	migrate.pgmap_owner = pdev;
	migrate.flags = MIGRATE_VMA_SELECT_DEVICE_PRIVATE;
	if (migrate_vma_setup(&migrate)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to setup migration after CPU page fault");
		goto fail_setup;
	}

	if (!migrate.cpages)
		return 0;

	src_page = migrate_pfn_to_page(src);
	if (!src_page || !(src & MIGRATE_PFN_MIGRATE))
		return 0;

	// allocate page on host
	dst_page = alloc_page_vma(GFP_HIGHUSER, vmf->vma, vmf->address);
	if (!dst_page) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate page for back migration after CPU page fault");
		goto fail_alloc;
	}

	lock_page(dst_page);
	dst = migrate_pfn(page_to_pfn(dst_page));

	// DMA transfer
	dma_addr = dma_map_page(&pci_dev->dev, dst_page, 0, PAGE_SIZE,
				DMA_FROM_DEVICE);
	if (dma_mapping_error(&pci_dev->dev, dma_addr)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to map page for DMA during back migration after CPU page fault");
		goto fail_map;
	}

	src_addr = pfn_to_dev_addr(svm_data, page_to_pfn(src_page));
	init_c2h_dma(svm_data, dma_addr, src_addr, 1, false);

	do {
		rval = readq(&svm_data->dma_regs->c2h_status_ctrl);
	} while (rval & PAGE_DMA_STAT_BUSY);
	if (rval & PAGE_DMA_STAT_ERROR_FLAGS) {
		DEVERR(pdev->parent->dev_id,
		       "DMA failed during back migration after CPU page fault");
		goto fail_dma;
	}
	dma_unmap_page(&pci_dev->dev, dma_addr, PAGE_SIZE, DMA_FROM_DEVICE);

	// finalize migration
	migrate_vma_pages(&migrate);
	migrate_vma_finalize(&migrate);

	// remove from virtual memory range list
	remove_vmem_interval(svm_data, vmf->address, 1);

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM, "finished migration to RAM");

	return 0;
fail_dma:
	dma_unmap_page(&pci_dev->dev, dma_addr, PAGE_SIZE, DMA_FROM_DEVICE);
fail_map:
	unlock_page(dst_page);
	__free_page(dst_page);
fail_alloc:
	dst = 0;
	migrate_vma_finalize(&migrate);
fail_setup:
	return VM_FAULT_SIGBUS;
}

static struct dev_pagemap_ops svm_pagemap_ops = {
	.page_free = kernel_page_free,
	.migrate_to_ram = svm_migrate_to_ram,
};

/**
 * Check whether two addresses refer to contiguous pages
 *
 * @param addr first address
 * @param last second address
 * @return true if the second address refers to the page preceding the page the
 * first address is referring to
 */
static inline int is_contiguous(uint64_t addr, uint64_t last)
{
	return ((addr & VADDR_MASK) == (last & VADDR_MASK) + PAGE_SIZE);
}

/**
 * Check whether two pages are in contiguous page frames
 *
 * @param page first page
 * @param last preceeding page
 * @return true if pages are in contiguous page frames
 */
static inline int is_contiguous_page(struct page *page, struct page *last)
{
	return (page == (last + 1));
}

/**
 * Enable and wait for a C2H interrupt of the PageDMA core
 *
 * @param svm_data SVM data struct
 */
static int wait_for_c2h_intr(struct tlkm_pcie_svm_data *svm_data)
{
	int res = 0;
	writeq(PAGE_DMA_CTRL_INTR_ENABLE, &svm_data->dma_regs->c2h_status_ctrl);
	if (wait_event_interruptible(
		    svm_data->wait_queue_c2h_intr,
		    atomic_read(&svm_data->wait_flag_c2h_intr))) {
		DEVWRN(svm_data->pdev->parent->dev_id,
		       "waiting for C2H IRQ interrupted by signal");
		res = -EINTR;
	}
	atomic_set(&svm_data->wait_flag_c2h_intr, 0);
	writeq(PAGE_DMA_CTRL_INTR_DISABLE | PAGE_DMA_CTRL_RESET_INTR,
	       &svm_data->dma_regs->c2h_status_ctrl);
	return res;
}

/**
 * Enable and wait for an H2C interrupt of the PageDMA core
 *
 * @param svm_data SVM data struct
 */
static int wait_for_h2c_intr(struct tlkm_pcie_svm_data *svm_data)
{
	int res = 0;
	writeq(PAGE_DMA_CTRL_INTR_ENABLE, &svm_data->dma_regs->h2c_status_ctrl);
	if (wait_event_interruptible(
		    svm_data->wait_queue_h2c_intr,
		    atomic_read(&svm_data->wait_flag_h2c_intr))) {
		DEVWRN(svm_data->pdev->parent->dev_id,
		       "Waiting for H2C IRQ interrupted by signal");
		res = -EINTR;
	}
	atomic_set(&svm_data->wait_flag_h2c_intr, 0);
	writeq(PAGE_DMA_CTRL_INTR_DISABLE | PAGE_DMA_CTRL_RESET_INTR,
	       &svm_data->dma_regs->h2c_status_ctrl);
	return res;
}

/**
 * Copy pages from one device to another using the Ethernet network connection.
 * Caller must check that both devices support migrations over the network.
 *
 * @param src_dev TLKM PCIe device struct of source device
 * @param dst_dev TLKM PCIe device struct of destination device
 * @param src_pages array with source pages to copy data from
 * @param dst_pages arrray with destination pages to copy data to
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int copy_dev_to_dev_network(struct tlkm_pcie_device *src_dev,
				   struct tlkm_pcie_device *dst_dev,
				   struct page **src_pages,
				   struct page **dst_pages, int npages)
{
	int i, res, ncontiguous;
	uint64_t dst_base;
	struct tlkm_pcie_svm_data *src_svm = src_dev->svm_data;
	struct tlkm_pcie_svm_data *dst_svm = dst_dev->svm_data;

	dst_base = pfn_to_dev_addr(dst_svm, page_to_pfn(dst_pages[0]));
	writeq(dst_svm->mac_addr, &src_svm->dma_regs->dst_mac);
	i = 0;
	while (i < npages) {
		// search for contiguous pages in source memory, always
		// contiguous in destination memory thanks to allocation scheme
		ncontiguous = 1;
		while (i + ncontiguous < npages &&
		       ncontiguous < PAGE_DMA_MAX_NPAGES) {
			if (is_contiguous_page(src_pages[i + ncontiguous],
					       src_pages[i + ncontiguous - 1]))
				++ncontiguous;
			else
				break;
		}
		init_c2h_dma(src_svm, 0, pfn_to_dev_addr(src_svm, page_to_pfn(
			src_pages[i])), ncontiguous, true);
		init_h2c_dma(dst_svm, 0, dst_base + i * PAGE_SIZE, ncontiguous,
			     false, true);
		i += ncontiguous;
	}

	res = wait_for_h2c_intr(dst_svm);
	if (res)
		return res;

	return 0;
}

/**
 * Copy pages from one device to another using endpoint-to-endpoint transfers
 * over PCIe. Caller must ensure that destination device exposes its memory
 * to the bus with an additional BAR.
 *
 * @param src_dev TLKM PCIe device struct of source device
 * @param dst_dev TLKM PCIe device struct of destination device
 * @param src_pages array with source pages to copy data from
 * @param dst_pages array with destination pages to copy data to
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int copy_dev_to_dev_pcie_e2e(struct tlkm_pcie_device *src_dev,
			      struct tlkm_pcie_device *dst_dev, struct page **src_pages, struct page **dst_pages, int npages)
{
	int i, res, ncontiguous, cmd_cnt;
	uint64_t dst_base, cmd_src, cmd_dst;
	struct tlkm_pcie_svm_data *src_svm = src_dev->svm_data;
	struct tlkm_pcie_svm_data *dst_svm = dst_dev->svm_data;

	DEVLOG(src_dev->parent->dev_id, TLKM_LF_SVM, "use PCIe P2P copy");

	dst_base = dst_svm->rdma_bar + pfn_to_dev_addr(dst_svm, page_to_pfn(dst_pages[0]));
	i = 0;
	cmd_cnt = 0;
	while (i < npages) {
		// search for contiguous pages in source memory, always
		// contiguous in destination memory thanks to allocation scheme
		ncontiguous = 1;
		while (i + ncontiguous < npages && ncontiguous < PAGE_DMA_MAX_NPAGES) {
			if (is_contiguous_page(src_pages[i + ncontiguous], src_pages[i + ncontiguous - 1]))
				++ncontiguous;
			else
				break;
		}

		// check whether PageDMA can accept further commands to
		// prevent deadlock on PCIe bus
		if (cmd_cnt >= 32 && readq(&src_svm->dma_regs->c2h_status_ctrl) & PAGE_DMA_STAT_FIFO_FULL) {
			res = wait_for_c2h_intr(src_svm);
			if (res)
				return res;
			cmd_cnt = 0;
		}

		// push data from source device to destination device
		cmd_src = pfn_to_dev_addr(src_svm, page_to_pfn(src_pages[i]));
		cmd_dst = dst_base + i * PAGE_SIZE;
		init_c2h_dma(src_svm, cmd_dst, cmd_src, ncontiguous, false);
		++cmd_cnt;
		i += ncontiguous;
	}

	res = wait_for_c2h_intr(src_svm);
	if (res)
		return res;
	return 0;
}

/**
 * Copy pages from one device to another in two steps using a buffer in host memory.
 *
 * @param src_dev TLKM PCIe device struct of source device
 * @param dst_dev TLKM PCIe device struct of destination device
 * @param src_pages array of source pages to copy data from
 * @param dst_pages array of destination pages to copy data to
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int copy_dev_to_dev_buffered(struct tlkm_pcie_device *src_dev,
				    struct tlkm_pcie_device *dst_dev,
				    struct page **src_pages,
				    struct page **dst_pages, int npages)
{
	int res, copied_pages, move_cnt, ncontiguous, cmd_cnt;
	size_t buf_size;
	void *buf;
	dma_addr_t buf_addr = 0;
	struct tlkm_pcie_svm_data *src_svm, *dst_svm;

	src_svm = src_dev->svm_data;
	dst_svm = dst_dev->svm_data;

	// maximum allocatable buffer is 4 MB (1024 pages)
	buf_size = min(npages, DEV_TO_DEV_DMA_MAX_NPAGES) * PAGE_SIZE;
	buf = kmalloc(buf_size, GFP_KERNEL);
	if (!buf) {
		DEVERR(dst_dev->parent->dev_id,
		       "failed to allocate buffer for device-to-device transfer");
		res = -ENOMEM;
		goto fail_alloc;
	}
	buf_addr = dma_map_single(&dst_dev->pdev->dev, buf, buf_size,
				  DMA_TO_DEVICE);
	if (dma_mapping_error(&dst_dev->pdev->dev, buf_addr)) {
		DEVERR(dst_dev->parent->dev_id,
		       "failed to map buffer for device-to-host transfer");
		res = -EACCES;
		goto fail_map;
	}

	copied_pages = 0;
	while (copied_pages < npages) {
		move_cnt = 0;
		cmd_cnt = 0;
		// search for contiguous source pages and move them to the host
		// buffer until it is filled completely
		while (copied_pages + move_cnt < npages &&
		       move_cnt < DEV_TO_DEV_DMA_MAX_NPAGES) {
			ncontiguous = 1;
			while (copied_pages + move_cnt + ncontiguous < npages &&
			       move_cnt + ncontiguous <
			       DEV_TO_DEV_DMA_MAX_NPAGES &&
			       ncontiguous < PAGE_DMA_MAX_NPAGES) {
				if (is_contiguous_page(
					src_pages[copied_pages + move_cnt +
						  ncontiguous],
					src_pages[copied_pages + move_cnt +
						  ncontiguous - 1]))
					++ncontiguous;
				else
					break;
			}

			// check whether PageDMA can accept further commands to
			// prevent deadlock on PCIe bus
			if (cmd_cnt >= 32 &&
			    readq(&src_svm->dma_regs->c2h_status_ctrl) &
			    PAGE_DMA_STAT_FIFO_FULL) {
				res = wait_for_c2h_intr(src_svm);
				if (res)
					goto fail_c2h;
				cmd_cnt = 0;
			}
			init_c2h_dma(src_svm, buf_addr + move_cnt * PAGE_SIZE,
				     pfn_to_dev_addr(src_svm, page_to_pfn(
					     src_pages[copied_pages +
						       move_cnt])), ncontiguous,
				     false);
			++cmd_cnt;
			move_cnt += ncontiguous;
		}

		res = wait_for_c2h_intr(src_dev->svm_data);
		if (res)
			goto fail_c2h;

		// move all pages with one command to destination memory
		// pages are always contiguous due to allocation scheme
		init_h2c_dma(dst_svm, buf_addr, pfn_to_dev_addr(dst_svm,
								page_to_pfn(
									dst_pages[copied_pages])),
			     move_cnt, false, false);
		res = wait_for_h2c_intr(dst_dev->svm_data);
		if (res)
			goto fail_h2c;

		copied_pages += move_cnt;
	}

	dma_unmap_single(&dst_dev->pdev->dev, buf_addr, buf_size,
			 DMA_TO_DEVICE);
	kfree(buf);
	return 0;

fail_h2c:
fail_c2h:
fail_map:
	dma_unmap_single(&dst_dev->pdev->dev, buf_addr, buf_size,
			 DMA_TO_DEVICE);
	kfree(buf);
fail_alloc:
	return res;
}

/**
 * Migrate range of virtually contiguous pages from RAM to device memory.
 * All pages are expected to reside in RAM, otherwise the migration is aborted.
 * Caller must hold the mmap_lock.
 *
 * @param pdev TLKM PCIe device struct of destination device
 * @param vaddr base address of migration range
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int svm_migrate_ram_to_dev(struct tlkm_pcie_device *pdev, uint64_t vaddr,
				  int npages)
{
	int res, i, j, ncontiguous, cmd_cnt, retry_cnt;
	bool clear;
	uint64_t dev_base_addr;
	unsigned long base_pfn;
	dma_addr_t *dma_addrs;
	struct page **src_pages, **dst_pages;
	struct migrate_vma migrate;
	struct vm_area_struct *vma;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "migrate %0d pages with base address %llx to device memory",
	       npages, vaddr);

	migrate.src = migrate.dst = NULL;
	migrate.src = kcalloc(npages, sizeof(*migrate.src), GFP_KERNEL);
	migrate.dst = kcalloc(npages, sizeof(*migrate.dst), GFP_KERNEL);
	src_pages = kcalloc(npages, sizeof(*src_pages), GFP_KERNEL);
	dst_pages = kcalloc(npages, sizeof(*dst_pages), GFP_KERNEL);
	dma_addrs = kcalloc(npages, sizeof(*dma_addrs), GFP_KERNEL);
	if (!migrate.src || !migrate.dst || !src_pages || !dst_pages ||
	    !dma_addrs) {
		DEVERR(pdev->parent->dev_id, "failed to allocate arrays");
		res = -ENOMEM;
		goto fail_alloc;
	}

	// find matching VMA
	migrate.start = vaddr;
	migrate.end = vaddr + npages * PAGE_SIZE;
	vma = find_vma_intersection(svm_data->mm, migrate.start, migrate.end);
	if (!vma) {
		DEVERR(pdev->parent->dev_id, "could not find matching VMA");
		res = -EFAULT;
		goto fail_vma;
	}

	// setup migration
	migrate.vma = vma;
	migrate.pgmap_owner = pdev;
	migrate.flags = MIGRATE_VMA_SELECT_SYSTEM;

retry:
	res = migrate_vma_setup(&migrate);
	if (res < 0) {
		DEVERR(pdev->parent->dev_id,
		       "failed to setup buffer migration");
		goto fail_setup;
	}

	// only perform migration for all pages together (unlikely to fail)
	if (migrate.cpages != npages) {
		migrate_vma_finalize(&migrate);
		++retry_cnt;
		if (retry_cnt > 3) {
			DEVERR(pdev->parent->dev_id,
			       "failed to collect all pages for migration");
			res = -ENOMEM;
			goto fail_setup;
		}
		goto retry;
	}

	// allocate device memory
	dev_base_addr = allocate_device_memory(svm_data,
					       npages * PAGE_SIZE);
	if (dev_base_addr == -1) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate memory on device");
		res = -ENOMEM;
		goto fail_allocmem;
	}
	base_pfn = dev_addr_to_pfn(svm_data, dev_base_addr);
	for (i = 0; i < npages; ++i) {
		dst_pages[i] = pfn_to_page(base_pfn + i);
		get_page(dst_pages[i]);
		lock_page(dst_pages[i]);
		migrate.dst[i] = migrate_pfn(base_pfn + i);
		dst_pages[i]->zone_device_data = pdev;
	}


	// map source pages for DMA transfer
	for (i = 0; i < npages; ++i) {
		src_pages[i] = migrate_pfn_to_page(migrate.src[i]);
		if (src_pages[i]) {
			dma_addrs[i] =
				dma_map_page(&pdev->pdev->dev, src_pages[i], 0,
					     PAGE_SIZE, DMA_TO_DEVICE);
			if (dma_mapping_error(&pdev->pdev->dev, dma_addrs[i])) {
				DEVWRN(pdev->parent->dev_id,
				       "failed to map page for DMA");
				unlock_page(dst_pages[i]);
				put_page(dst_pages[i]);
				dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
					       PAGE_SIZE, DMA_TO_DEVICE);
				dma_addrs[i] = 0;
				res = -EACCES;
				goto fail_dmamap;
			}
		}
	}

	i = 0;
	cmd_cnt = 0;
	while (i < npages) {
		// find physical contiguous region on host side
		// (always contiguous on device side due to allocation scheme)
		ncontiguous = 1;
		if (src_pages[i]) {
			clear = false;
			while (i + ncontiguous < npages &&
			       ncontiguous < PAGE_DMA_MAX_NPAGES &&
			       src_pages[i + ncontiguous]) {
				if (is_contiguous(
					    dma_addrs[i + ncontiguous],
					    dma_addrs[i + ncontiguous - 1]))
					++ncontiguous;
				else
					break;
			}
		} else {
			clear = true;
			while (i + ncontiguous < npages &&
			       ncontiguous < PAGE_DMA_MAX_NPAGES &&
			       !src_pages[i + ncontiguous] )
				++ncontiguous;
		}

		// check whether PageDMA can accept further commands to prevent
		// deadlock on PCIe bus
		if (cmd_cnt >= 32 &&
		    readq(&svm_data->dma_regs->h2c_status_ctrl) &
			    PAGE_DMA_STAT_FIFO_FULL) {
			res = wait_for_h2c_intr(svm_data);
			if (res)
				goto fail_dma;
			cmd_cnt = 0;
		}
		init_h2c_dma(svm_data, dma_addrs[i],
			     pfn_to_dev_addr(svm_data, base_pfn + i),
			     ncontiguous, clear, false);
		++cmd_cnt;

		i += ncontiguous;
	}
	res = wait_for_h2c_intr(svm_data);
	if (res)
		goto fail_dma;

	if (readq(&svm_data->dma_regs->h2c_status_ctrl) &
	    PAGE_DMA_STAT_ERROR_FLAGS) {
		DEVERR(pdev->parent->dev_id, "DMA during migration failed");
		res = -EACCES;
		goto fail_dma;
	}

	// release dma mappings
	for (i = 0; i < npages; ++i) {
		if (dma_addrs[i])
			dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
				       PAGE_SIZE, DMA_TO_DEVICE);
	}

	migrate_vma_pages(&migrate);
	for (i = 0; i < npages; ++i) {
		// check for successful migration
		if (!(migrate.src[i] & MIGRATE_PFN_MIGRATE)) {
			for (j = 0; j < npages; ++j) {
				unlock_page(dst_pages[j]);
				put_page(dst_pages[j]);
				dst_pages[j] = NULL;
				migrate.dst[j] = 0;
			}
			migrate_vma_finalize(&migrate);
			++retry_cnt;
			if (retry_cnt > 4) {
				DEVERR(pdev->parent->dev_id,
				       "failed to migrate all pages");
				res = -ENOMEM;
				goto fail_migrate;
			}
			goto retry;
		}
	}

	// add TLB entries and collect pages which could not be migrated
	// first and last page are always added independently
	add_tlb_entry(svm_data, vaddr, pfn_to_dev_addr(svm_data, base_pfn));
	i = 1;
	while (i < npages - 1) {
		ncontiguous = min(npages - 1 - i, MMU_MAX_MAPPING_LENGTH);
		// only use arbitrary length TLB mappings for contiguous regions
		// to save resources
		if (ncontiguous >= 64) {
			add_al_tlb_entry(svm_data, vaddr + i * PAGE_SIZE,
					 pfn_to_dev_addr(svm_data,
							 base_pfn + i),
					 ncontiguous);
		} else {
			for (j = i; j < (i + ncontiguous); ++j)
				add_tlb_entry(svm_data, vaddr + j * PAGE_SIZE,
					      pfn_to_dev_addr(svm_data,
							      base_pfn + j));
		}
		i += ncontiguous;
	}
	if (i < npages)
		add_tlb_entry(svm_data, vaddr + i * PAGE_SIZE,
			      pfn_to_dev_addr(svm_data, base_pfn + i));

	migrate_vma_finalize(&migrate);

	// add virtual memory interval to interval tree
	insert_vmem_interval(svm_data, vaddr, npages);

	kfree(dma_addrs);
	kfree(dst_pages);
	kfree(src_pages);
	kfree(migrate.dst);
	kfree(migrate.src);

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "migration to device memory complete");

	return 0;

fail_dma:
fail_dmamap:
	for (i = 0; i < npages; ++i) {
		if (dma_addrs[i])
			dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
				       PAGE_SIZE, DMA_TO_DEVICE);
	}
fail_allocmem:
	for (i = 0; i < npages; ++i) {
		if (dst_pages[i]) {
			unlock_page(dst_pages[i]);
			put_page(dst_pages[i]);
		}
		migrate.dst[i] = 0;
	}
	migrate_vma_finalize(&migrate);
fail_migrate:
fail_setup:
fail_vma:
fail_alloc:
	if (dma_addrs)
		kfree(dma_addrs);
	if (dst_pages)
		kfree(dst_pages);
	if (src_pages)
		kfree(src_pages);
	if (migrate.dst)
		kfree(migrate.dst);
	if (migrate.src)
		kfree(migrate.src);
	return res;
}

/**
 * Migrate range of virtually contiguous pages from one device to another.
 * All pages must reside on the source device, otherwise the migration is aborted.
 * Caller must hold mmap lock.
 *
 * @param src_dev TLKM PCIe device struct of source device
 * @param dst_dev TLKM PCIe device struct of destination device
 * @param vaddr virtual base address of migration range
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int svm_migrate_dev_to_dev(struct tlkm_pcie_device *src_dev,
				  struct tlkm_pcie_device *dst_dev,
				  uint64_t vaddr, int npages)
{
	int res, i, j, ncontiguous, retry_cnt;
	uint64_t dev_base_addr;
	unsigned long base_pfn;
	struct page **src_pages, **dst_pages;
	struct migrate_vma migrate;
	struct vm_area_struct *vma;
	struct tlkm_pcie_svm_data *src_svm, *dst_svm;

	src_svm = src_dev->svm_data;
	dst_svm = dst_dev->svm_data;

	DEVLOG(dst_dev->parent->dev_id, TLKM_LF_SVM,
	       "migrate %0d pages with base address %llx from device #%2d to device memory",
	       npages, vaddr, src_dev->parent->dev_id);

	migrate.src = migrate.dst = NULL;
	migrate.src = kcalloc(npages, sizeof(*migrate.src), GFP_KERNEL);
	migrate.dst = kcalloc(npages, sizeof(*migrate.dst), GFP_KERNEL);
	src_pages = kcalloc(npages, sizeof(*src_pages), GFP_KERNEL);
	dst_pages = kcalloc(npages, sizeof(*dst_pages), GFP_KERNEL);
	if (!migrate.src || !migrate.dst || !src_pages || !dst_pages) {
		DEVERR(dst_dev->parent->dev_id, "failed to allocate arrays");
		res = -ENOMEM;
		goto fail_alloc;
	}

	// find matching VMA
	migrate.start = vaddr;
	migrate.end = vaddr + npages * PAGE_SIZE;
	vma = find_vma_intersection(dst_svm->mm, migrate.start, migrate.end);
	if (!vma) {
		DEVERR(dst_dev->parent->dev_id, "could not find matching VMA");
		res = -EFAULT;
		goto fail_vma;
	}

	// deactivate MMU, invalidate TLBs and wait for ongoing accesses
	writeq(MMU_DEACTIVATE, &src_svm->mmu_regs->cmd);
	invalidate_tlb_range(src_svm, vaddr, npages);
	while (readq(&src_svm->mmu_regs->status) & MMU_STATUS_ANY_MEM_ACCESS);
	writeq(MMU_ACTIVATE, &src_svm->mmu_regs->cmd);

	// setup migration
	migrate.vma = vma;
	migrate.pgmap_owner = src_dev;
	migrate.flags = MIGRATE_VMA_SELECT_DEVICE_PRIVATE;

retry:
	res = migrate_vma_setup(&migrate);
	if (res < 0) {
		DEVERR(dst_dev->parent->dev_id,
		       "failed to setup buffer migration");
		goto fail_setup;
	}

	// only perform migration for all pages together (unlikely to fail)
	if (migrate.cpages != npages) {
		migrate_vma_finalize(&migrate);
		++retry_cnt;
		if (retry_cnt > 3) {
			DEVERR(dst_dev->parent->dev_id, "failed to collect all pages for migration");
			res = -ENOMEM;
			goto fail_setup;
		}
		goto retry;
	}

	// allocate device memory
	dev_base_addr = allocate_device_memory(dst_svm,
					       npages * PAGE_SIZE);
	if (dev_base_addr == -1) {
		DEVERR(dst_dev->parent->dev_id,
		       "failed to allocate memory on device");
		res = -ENOMEM;
		goto fail_allocmem;
	}
	base_pfn = dev_addr_to_pfn(dst_svm, dev_base_addr);
	for (i = 0; i < npages; ++i) {
		src_pages[i] = migrate_pfn_to_page(migrate.src[i]);
		dst_pages[i] = pfn_to_page(base_pfn + i);
		get_page(dst_pages[i]);
		lock_page(dst_pages[i]);
		migrate.dst[i] = migrate_pfn(base_pfn + i);
		dst_pages[i]->zone_device_data = dst_dev;
	}

	// choose copy method based on capabilities
	if (src_svm->network_dma_enabled && dst_svm->network_dma_enabled)
		res = copy_dev_to_dev_network(src_dev, dst_dev, src_pages,
					      dst_pages, npages);
		// since data is pushed, only destination device must expose memory
		// to the PCIe bus
	else if (dst_svm->rdma_bar)
		res = copy_dev_to_dev_pcie_e2e(src_dev, dst_dev, src_pages,
					       dst_pages, npages);
	else
		res = copy_dev_to_dev_buffered(src_dev, dst_dev, src_pages,
					       dst_pages, npages);
	if (res) {
		DEVERR(dst_dev->parent->dev_id,
		       "DMA during migration failed");
		goto fail_dma;
	}

	if (readq(&src_svm->dma_regs->c2h_status_ctrl) &
	    PAGE_DMA_STAT_ERROR_FLAGS ||
	    readq(&dst_svm->dma_regs->h2c_status_ctrl) &
	    PAGE_DMA_STAT_ERROR_FLAGS) {
		DEVERR(dst_dev->parent->dev_id, "DMA during migration failed");
		res = -EACCES;
		goto fail_dma;
	}

	migrate_vma_pages(&migrate);
	for (i = 0; i < npages; ++i) {
		// check for successful migration
		if (!(migrate.src[i] & MIGRATE_PFN_MIGRATE)) {
			for (j = 0; j < npages; ++j) {
				unlock_page(dst_pages[j]);
				put_page(dst_pages[j]);
				dst_pages[j] = NULL;
				migrate.dst[j] = 0;
			}
			migrate_vma_finalize(&migrate);
			DEVERR(dst_dev->parent->dev_id,
			       "failed to migrate all pages");
			res = -ENOMEM;
			goto fail_migrate;
		}
	}

	// add TLB entries
	// first and last page are always added independently
	add_tlb_entry(dst_svm, vaddr, pfn_to_dev_addr(dst_svm, base_pfn));
	i = 1;
	while (i < npages - 1) {
		ncontiguous = min(npages - 1 - i, MMU_MAX_MAPPING_LENGTH);
		// only use arbitrary length TLB mappings for contiguous regions
		// to save resources
		if (ncontiguous >= 64) {
			add_al_tlb_entry(dst_svm, vaddr + i * PAGE_SIZE,
					 pfn_to_dev_addr(dst_svm,
							 base_pfn + i),
					 ncontiguous);
		} else {
			for (j = i; j < (i + ncontiguous); ++j)
				add_tlb_entry(dst_svm, vaddr + j * PAGE_SIZE,
					      pfn_to_dev_addr(dst_svm,
							      base_pfn + j));
		}
		i += ncontiguous;
	}
	if (i < npages)
		add_tlb_entry(dst_svm, vaddr + i * PAGE_SIZE,
			      pfn_to_dev_addr(dst_svm, base_pfn + i));

	i = 0;
	while (i < npages) {
		ncontiguous = 1;
		src_pages[i]->zone_device_data = NULL;
		while (i + ncontiguous < npages) {
			if (is_contiguous_page(src_pages[i + ncontiguous],
					       src_pages[i + ncontiguous -
							 1])) {
				src_pages[i +
					  ncontiguous]->zone_device_data = NULL;
				++ncontiguous;
			} else {
				break;
			}
		}
		if (!queue_dev_mem_free_work(src_dev, pfn_to_dev_addr(src_svm,
								      page_to_pfn(
									      src_pages[i])),
					     ncontiguous * PAGE_SIZE))
			DEVERR(src_dev->parent->dev_id,
			       "failed to queue work struct to free memory");
		i += ncontiguous;
	}

	migrate_vma_finalize(&migrate);

	// remove/add virtual memory intervals
	remove_vmem_interval(src_svm, vaddr, npages);
	insert_vmem_interval(dst_svm, vaddr, npages);

	kfree(dst_pages);
	kfree(src_pages);
	kfree(migrate.dst);
	kfree(migrate.src);

	DEVLOG(dst_dev->parent->dev_id, TLKM_LF_SVM,
	       "migration to device memory complete");

	return 0;

fail_dma:
fail_allocmem:
	for (i = 0; i < npages; ++i) {
		if (dst_pages[i]) {
			unlock_page(dst_pages[i]);
			put_page(dst_pages[i]);
		}
		migrate.dst[i] = 0;
	}
	migrate_vma_finalize(&migrate);
fail_migrate:
fail_setup:
fail_vma:
fail_alloc:
	if (dst_pages)
		kfree(dst_pages);
	if (src_pages)
		kfree(src_pages);
	if (migrate.dst)
		kfree(migrate.dst);
	if (migrate.src)
		kfree(migrate.src);
	return res;
}

/**
 * Migrate virtually contiguous pages from device memory to RAM.
 * All pages must reside in device memory, otherwise the migration is aborted.
 * Caller must hold mmap lock.
 *
 * @param pdev TLKM PCIe device struct of source device
 * @param vaddr virtual base address of migration range
 * @param npages number of pages to migrate
 * @return SUCCESS - 0, FAILURE - error code
 */
static int svm_migrate_dev_to_ram(struct tlkm_pcie_device *pdev, uint64_t vaddr,
				  int npages)
{
	int res, i, j, ncontiguous, cmd_cnt, retry_cnt;
	dma_addr_t *dma_addrs;
	struct page **src_pages, **dst_pages;
	struct migrate_vma migrate;
	struct vm_area_struct *vma;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "migrate %0d pages with base address %llx to RAM",
	       npages, vaddr);

	migrate.src = migrate.dst = NULL;
	migrate.src = kcalloc(npages, sizeof(*migrate.src), GFP_KERNEL);
	migrate.dst = kcalloc(npages, sizeof(*migrate.dst), GFP_KERNEL);
	src_pages = kcalloc(npages, sizeof(*src_pages), GFP_KERNEL);
	dst_pages = kcalloc(npages, sizeof(*dst_pages), GFP_KERNEL);
	dma_addrs = kcalloc(npages, sizeof(*dma_addrs), GFP_KERNEL);
	if (!migrate.src || !migrate.dst || !src_pages || !dst_pages ||
	    !dma_addrs) {
		DEVERR(pdev->parent->dev_id, "failed to allocate arrays");
		goto fail_alloc;
	}

	// find matching VMA
	migrate.start = vaddr;
	migrate.end = vaddr + npages * PAGE_SIZE;
	vma = find_vma_intersection(svm_data->mm, migrate.start, migrate.end);
	if (!vma) {
		DEVERR(pdev->parent->dev_id, "could not find matching VMA");
		res = -EFAULT;
		goto fail_vma;
	}

	// deactivate MMU, invalidate all entries, and wait for active memory
	// accesses to finish
	writeq(MMU_DEACTIVATE, &svm_data->mmu_regs->cmd);
	invalidate_tlb_range(svm_data, vaddr, npages);
	while (readq(&svm_data->mmu_regs->status) & MMU_STATUS_ANY_MEM_ACCESS);

	// setup migration
	migrate.vma = vma;
	migrate.pgmap_owner = pdev;
	migrate.flags = MIGRATE_VMA_SELECT_DEVICE_PRIVATE;

retry:
	res = migrate_vma_setup(&migrate);
	if (res < 0) {
		DEVERR(pdev->parent->dev_id, "failed to setup migration");
		goto fail_setup;
	}

	// only perform migration for all pages together (unlikely to fail)
	if (migrate.cpages != npages) {
		migrate_vma_finalize(&migrate);
		++retry_cnt;
		if (retry_cnt > 3) {
			DEVERR(pdev->parent->dev_id,
			       "failed to collect all pages for migration");
			res = -ENOMEM;
			goto fail_setup;
		}
		goto retry;
	}

	// allocate pages in host memory and create DMA mappings
	for (i = 0; i < npages; ++i) {
		src_pages[i] = migrate_pfn_to_page(migrate.src[i]);
		dst_pages[i] = alloc_page_vma(GFP_HIGHUSER, vma,
					      vaddr + i * PAGE_SIZE);
		if (!dst_pages[i]) {
			DEVERR(pdev->parent->dev_id,
			       "failed to allocate page on host for migration");
			res = -ENOMEM;
			goto fail_allocpage;
		}
		lock_page(dst_pages[i]);
		migrate.dst[i] = migrate_pfn(page_to_pfn(dst_pages[i]));
		dma_addrs[i] = dma_map_page(&pdev->pdev->dev, dst_pages[i], 0,
					    PAGE_SIZE, DMA_FROM_DEVICE);
		if (dma_mapping_error(&pdev->pdev->dev, dma_addrs[i])) {
			DEVWRN(pdev->parent->dev_id,
			       "failed to map page for DMA");
			unlock_page(dst_pages[i]);
			__free_page(dst_pages[i]);
			dst_pages[i] = NULL;
			dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
				       PAGE_SIZE, DMA_TO_DEVICE);
			migrate.dst[i] = 0;
			dma_addrs[i] = 0;
			res = -EACCES;
			goto fail_dmamap;
		}
	}

	i = 0;
	cmd_cnt = 0;
	while (i < npages) {
		// find physical contiguous regions on host and device side
		ncontiguous = 1;
		while (i + ncontiguous < npages &&
		       ncontiguous < PAGE_DMA_MAX_NPAGES) {
			if (is_contiguous(dma_addrs[i + ncontiguous],
					  dma_addrs[i + ncontiguous - 1]) &&
			    is_contiguous_page(src_pages[i + ncontiguous],
					       src_pages[i + ncontiguous - 1]))
				++ncontiguous;
			else
				break;
		}

		// check whether PageDMA can accept further commands to prevent
		// deadlock on PCIe bus
		if (cmd_cnt >= 32 &&
		    readq(&svm_data->dma_regs->c2h_status_ctrl) &
			    PAGE_DMA_STAT_FIFO_FULL) {
			wait_for_c2h_intr(svm_data);
			cmd_cnt = 0;
		}
		init_c2h_dma(svm_data, dma_addrs[i], pfn_to_dev_addr(svm_data,
								     page_to_pfn(
									     src_pages[i])),
			     ncontiguous, false);
		++cmd_cnt;
		i += ncontiguous;
	}

	res = wait_for_c2h_intr(svm_data);
	if (res)
		goto fail_dma;

	if (readq(&svm_data->dma_regs->c2h_status_ctrl) &
	    PAGE_DMA_STAT_ERROR_FLAGS) {
		DEVERR(pdev->parent->dev_id,
		       "DMA during migration to host failed");
		res = -EACCES;
		goto fail_dma;
	}

	// release DMA mappings
	for (i = 0; i < npages; ++i) {
		if (dma_addrs[i])
			dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
				       PAGE_SIZE, DMA_FROM_DEVICE);
	}

	// check for successful migration
	migrate_vma_pages(&migrate);
	for (i = 0; i < npages; ++i) {
		if (!(migrate.src[i] & MIGRATE_PFN_MIGRATE)) {
			// should never happen, but abort migration
			for (j = 0; j < npages; ++j) {
				unlock_page(dst_pages[j]);
				__free_page(dst_pages[j]);
				dst_pages[j] = NULL;
				migrate.dst[j] = 0;
			}
			migrate_vma_finalize(&migrate);
			DEVERR(pdev->parent->dev_id,
			       "failed to migrate all pages");
			res = -ENOMEM;
			goto fail_migrate;
		}
	}

	i = 0;
	while (i < npages) {
		src_pages[i]->zone_device_data = NULL;
		ncontiguous = 1;
		while (i + ncontiguous < npages) {
			if (is_contiguous_page(src_pages[i + ncontiguous],
					       src_pages[i + ncontiguous -
							 1])) {
				src_pages[i +
					  ncontiguous]->zone_device_data = NULL;
				++ncontiguous;
			} else {
				break;
			}
		}

		if (!queue_dev_mem_free_work(pdev, pfn_to_dev_addr(svm_data,
								   page_to_pfn(
									   src_pages[i])),
					     ncontiguous * PAGE_SIZE))
			DEVERR(pdev->parent->dev_id,
			       "failed to queue work struct to free memory");
		i += ncontiguous;
	}

	migrate_vma_finalize(&migrate);

	// remove virtual memory interval from tree
	remove_vmem_interval(svm_data, vaddr, npages);

	writeq(MMU_ACTIVATE, &svm_data->mmu_regs->cmd);
	kfree(dma_addrs);
	kfree(dst_pages);
	kfree(src_pages);
	kfree(migrate.dst);
	kfree(migrate.src);

	return 0;

fail_dma:
fail_dmamap:
fail_allocpage:
	for (i = 0; i < npages; ++i) {
		if (dst_pages[i]) {
			if (dma_addrs[i])
				dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
					       PAGE_SIZE, DMA_FROM_DEVICE);
			unlock_page(dst_pages[i]);
			__free_page(dst_pages[i]);
		}
		migrate.dst[i] = 0;
	}
	migrate_vma_finalize(&migrate);
fail_migrate:
fail_setup:
	writeq(MMU_ACTIVATE, &svm_data->mmu_regs->cmd);
fail_vma:
fail_alloc:
	if (migrate.src)
		kfree(migrate.src);
	if (migrate.dst)
		kfree(migrate.dst);
	if (src_pages)
		kfree(src_pages);
	if (dst_pages)
		kfree(dst_pages);
	if (dma_addrs)
		kfree(dma_addrs);
	return res;
}

/**
 * Migrate multiple pages with contiguous virtual addresses to device memory.
 * Pages may reside in different memories. Function determines source memories
 * and calls the respective sub-routines.
 * Caller must hold the mmap lock.
 *
 * @param pdev TLKM PCIe device struct of destination device
 * @param vaddr virtual address of the first page
 * @param npages number of contiguous pages
 * @param drop_failed if true: send drop commands to IOMMU for failed migrations
 * @return SUCCESS - 0, FAILURE - error code
 */
static int svm_migrate_to_device(struct tlkm_pcie_device *pdev, uint64_t vaddr,
				 int npages, bool drop_failed)
{
	int r, res = 0, i, j, ndevs, next_dev, nmigrate;
	uint64_t curr_addr;
	unsigned long next_start, end;
	struct tlkm_device *d;
	struct tlkm_pcie_device *src_dev;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data, *src_svm;
	struct list_head *vmem_intervals;
	struct vmem_interval_list_entry *entry, *next_entry;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "migrate %0d pages with base address %llx to device memory",
	       npages, vaddr);

	ndevs = tlkm_bus_num_devices();
	vmem_intervals = kcalloc(ndevs, sizeof(*vmem_intervals), GFP_KERNEL);
	if (!vmem_intervals) {
		DEVERR(pdev->parent->dev_id, "failed to allocate array");
		return -ENOMEM;
	}

	// get virtual memory intervals of all devices in same process
	for (i = 0; i < ndevs; ++i) {
		INIT_LIST_HEAD(&vmem_intervals[i]);
		d = tlkm_bus_get_device(i);
		if (d->vendor_id != 0x10EE || d->product_id != 0x7038)
			continue;
		src_dev = d->private_data;
		src_svm = src_dev->svm_data;
		if (!src_svm || src_svm->mm != svm_data->mm)
			continue;

		if (search_vmem_intervals(src_svm, &vmem_intervals[i], vaddr,
					  npages)) {
			DEVERR(src_dev->parent->dev_id,
			       "error during search for vmem intervals");
			continue;
		}
	}

	i = 0;
	curr_addr = vaddr;
	end = vaddr + npages * PAGE_SIZE;
	while (i < npages) {
		// search next interval on any device
		next_dev = -1;
		next_start = -1;
		next_entry = NULL;
		curr_addr = vaddr + i * PAGE_SIZE;
		for (j = 0; j < ndevs; ++j) {
			if (list_empty(&vmem_intervals[j]))
				continue;

			entry = list_first_entry(&vmem_intervals[j],
			struct vmem_interval_list_entry, list);
			if (entry->interval_node->start < next_start) {
				next_start = entry->interval_node->start;
				next_dev = j;
				next_entry = entry;
			}
		}

		// interval is located in RAM
		if (next_start > curr_addr) {
			nmigrate = (min(next_start, end) - curr_addr)
				>> PAGE_SHIFT;
			r = svm_migrate_ram_to_dev(pdev, curr_addr, nmigrate);
			if (r) {
				res = r;
				if (drop_failed) {
					for (j = 0; j < nmigrate; ++j)
						drop_page_fault(svm_data,
								curr_addr +
								j * PAGE_SIZE);
				}
			}
			i += nmigrate;
			curr_addr = vaddr + i * PAGE_SIZE;
		}

		// migrate next interval
		if (next_start != -1) {
			nmigrate =
				(min(next_entry->interval_node->last + 1, end) -
				 curr_addr) >> PAGE_SHIFT;
			src_dev = tlkm_bus_get_device(next_dev)->private_data;
			if (src_dev != pdev) {
				r = svm_migrate_dev_to_dev(src_dev, pdev,
							   curr_addr, nmigrate);
				if (r) {
					res = r;
					if (drop_failed) {
						for (j = 0; j < nmigrate; ++j)
							drop_page_fault(
								svm_data,
								curr_addr +
								j * PAGE_SIZE);
					}
				}
			}
			list_del(&next_entry->list);
			kfree(next_entry);
			i += nmigrate;
		}

	}

	kfree(vmem_intervals);
	return res;
}

/**
 * Execute user managed migration of a memory regionto device memory.
 * Source pages may reside in different memories.
 *
 * @param inst TLKM device struct
 * @param vaddr virtual base address of the memory region
 * @param size size of the memory region in bytes
 * @return Zero when succeeding, error code in case of failure
 */
int pcie_svm_user_managed_migration_to_device(struct tlkm_device *inst,
					      uint64_t vaddr, uint64_t size)
{
	int res, npages;
	uint64_t va_start, va_end;
	struct tlkm_pcie_device *pdev = inst->private_data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	if (!svm_data) {
		DEVERR(pdev->parent->dev_id, "SVM not supported by bitstream");
		return -EFAULT;
	}

	DEVLOG(inst->dev_id, TLKM_LF_SVM,
	       "user managed migration to device with vaddr = %llx, size = %llx",
	       vaddr, size);

	// align start and end to page boundaries
	va_start = vaddr & PAGE_MASK;
	va_end = vaddr + size;
	va_end = (va_end & ~PAGE_MASK) ? ((va_end & PAGE_MASK) + PAGE_SIZE) :
					       (va_end & PAGE_MASK);
	npages = (va_end - va_start) >> PAGE_SHIFT;

	mmget(svm_data->mm);
	mmap_write_lock(svm_data->mm);

	res = svm_migrate_to_device(pdev, va_start, npages, false);

	mmap_write_unlock(svm_data->mm);
	mmput(svm_data->mm);

	if (res) {
		DEVERR(inst->dev_id,
		       "failed to migrate memory region to device");
		return res;
	}

	return 0;
}

/**
 * Execute user managed migration of a memory region to host memory.
 * Source pages may reside in different memories
 *
 * @param inst TLKM device struct
 * @param vaddr virtual base address of the memory region
 * @param size size of the memory region in bytes
 * @return Zero when succeeding, error code in case of failure
 */
int pcie_svm_user_managed_migration_to_ram(struct tlkm_device *inst,
					   uint64_t vaddr, uint64_t size)
{
	int r, res = 0, i, npages, ndevs, nmigrate;
	unsigned long va_start, va_end, start, end;
	struct tlkm_device *d;
	struct tlkm_pcie_device *pdev = inst->private_data, *src_dev;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data, *src_svm;
	struct list_head vmem_intervals;
	struct vmem_interval_list_entry *entry;

	if (!svm_data) {
		DEVERR(pdev->parent->dev_id, "SVM not supported by bitstream");
		return -EFAULT;
	}

	DEVLOG(inst->dev_id, TLKM_LF_SVM,
	       "user managed migration to host with vaddr = %llx, size = %llx",
	       vaddr, size);

	// align start and end to page boundaries
	va_start = vaddr & PAGE_MASK;
	va_end = vaddr + size;
	va_end = (va_end & ~PAGE_MASK) ? ((va_end & PAGE_MASK) + PAGE_SIZE) :
					       (va_end & PAGE_MASK);
	npages = (va_end - va_start) >> PAGE_SHIFT;

	mmget(svm_data->mm);
	mmap_write_lock(svm_data->mm);

	// search and migrate intervals from all devices
	ndevs = tlkm_bus_num_devices();
	INIT_LIST_HEAD(&vmem_intervals);
	for (i = 0; i < ndevs; ++i) {
		d = tlkm_bus_get_device(i);
		if (d->vendor_id != 0x10EE || d->product_id != 0x7038)
			continue;
		src_dev = d->private_data;
		src_svm = src_dev->svm_data;
		if (!src_svm || src_svm->mm != svm_data->mm)
			continue;

		if (search_vmem_intervals(src_svm, &vmem_intervals, vaddr,
					  npages)) {
			DEVERR(src_dev->parent->dev_id,
			       "error during search for vmem intervals");
			continue;
		}

		while (!list_empty(&vmem_intervals)) {
			entry = list_first_entry(&vmem_intervals,
			struct vmem_interval_list_entry, list);
			start = max(va_start, entry->interval_node->start);
			end = min(entry->interval_node->last + 1, va_end);
			nmigrate = (end - start) >> PAGE_SHIFT;
			r = svm_migrate_dev_to_ram(src_dev, start, nmigrate);
			if (r)
				res = r;

			list_del(&entry->list);
			kfree(entry);
		}
	}

	mmap_write_unlock(svm_data->mm);
	mmput(svm_data->mm);

	return res;
}

/**
 * Compare two virtual addresses, used for sort function
 *
 * @param p1 first address
 * @param p2 second address
 * @return 1 if p1 > p2, -1 if p1 < p2, 0 if p1 == p2
 */
static int svm_cmp_addr(const void *p1, const void *p2)
{
	const uint64_t addr_1 = *((uint64_t *)p1) & VADDR_MASK;
	const uint64_t addr_2 = *((uint64_t *)p2) & VADDR_MASK;
	return (addr_1 > addr_2) - (addr_1 < addr_2);
}

/**
 * remove duplicates in a sorted array of addresses
 *
 * @param array: array with duplicates
 * @param size: size of input array
 * @return new size of array
 */
int remove_duplicates(uint64_t *array, int size)
{
	int i, j;
	i = 1;
	while (i < size) {
		if ((array[i] & VADDR_MASK) == (array[i - 1] & VADDR_MASK)) {
			// entry equals previous entry -> remove it by moving all following entries one position
			for (j = i; j < size - 1; ++j) {
				array[j] = array[j + 1];
			}
			--size;
		} else {
			++i;
		}
	}
	return size;
}

/**
 * remove zero entries in an array
 *
 * @param array array with zeros
 * @param size size of array
 * @return new size of array
 */
static int pack_array(uint64_t *array, int size)
{
	int idx, j, gap;
	for (idx = 0; idx < size; ++idx) {
		if (!array[idx]) {
			gap = 1;
			while ((idx + gap) < size && !array[idx + gap])
				++gap;
			for (j = idx; j < size - gap; ++j)
				array[j] = array[j + gap];
			size -= gap;
		}
	}
	return size;
}

/**
 * Perform a PTW to find the device private page for a virtual address
 *
 * @param svm_data SVM data struct
 * @param vaddr virtual address
 * @return pointer to device private page or NULL if the requested page is not
 * present in device memory
 */
static struct page *svm_perform_ptw(struct tlkm_pcie_svm_data *svm_data,
				    uint64_t vaddr)
{
	pgd_t *pgd;
	p4d_t *p4d;
	pud_t *pud;
	pmd_t *pmd;
	pte_t *pte;
	spinlock_t *ptl;
	swp_entry_t swp;
	struct page *page;

	pgd = pgd_offset(svm_data->mm, vaddr);
	if (pgd_none(*pgd) || unlikely(pgd_bad(*pgd))) {
		DEVWRN(svm_data->pdev->parent->dev_id,
		       "PGD not found during page table walk");
		goto no_pgd;
	}
	p4d = p4d_offset(pgd, vaddr);
	if (p4d_none(*p4d) || unlikely(p4d_bad(*p4d))) {
		DEVWRN(svm_data->pdev->parent->dev_id,
		       "P4D not found during page table walk");
		goto no_p4d;
	}
	pud = pud_offset(p4d, vaddr);
	if (pud_none(*pud) || unlikely(pud_bad(*pud))) {
		DEVWRN(svm_data->pdev->parent->dev_id,
		       "PUD not found during page table walk");
		goto no_pud;
	}
	pmd = pmd_offset(pud, vaddr);
	if (pmd_none(*pmd))
		goto no_pmd;
	pte = pte_offset_map_lock(svm_data->mm, pmd, vaddr, &ptl);
	if (pte_none(*pte) || pte_present(*pte))
		goto no_pte_or_present;
	swp = pte_to_swp_entry(*pte);
	if (!is_device_private_entry(swp))
		goto not_dev_priv;
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 14, 0)
	page = pfn_swap_entry_to_page(swp);
#else
	page = device_private_entry_to_page(swp);
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,14,0) */
	pte_unmap_unlock(pte, ptl);
	return page;

not_dev_priv:
no_pte_or_present:
	pte_unmap_unlock(pte, ptl);
no_pmd:
no_pud:
no_p4d:
no_pgd:
	return NULL;
}

/**
 * Handle device page faults by the on-FPGA IOMMU
 *
 * @param work work struct containing required data for the cmwq worker thread
 */
static void handle_iommu_page_fault(struct work_struct *work)
{
	int res, i, nfaults, ncontiguous;
	uint64_t rval, vaddrs[MAX_NUM_FAULTS];
	uint64_t dev_addr;
	struct page *page;
	struct page_fault_work_env *env =
		container_of(work, typeof(*env), work);
	struct tlkm_pcie_device *pdev = env->pdev;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "start IOMMU page fault handling");

	nfaults = 0;
	while (1) {
		// stop issuing additional faults during fault handling
		writeq(0, &svm_data->mmu_regs->intr_enable);

		while (nfaults < MAX_NUM_FAULTS) {
			rval = readq(&svm_data->mmu_regs->faulted_vaddr);
			if (!(rval & VALID_ADDR_FLAG))
				break;
			vaddrs[nfaults] = rval & VADDR_MASK;
			++nfaults;
		}

		if (!nfaults)
			break;

		sort(vaddrs, nfaults, sizeof(*vaddrs), svm_cmp_addr, NULL);
		nfaults = remove_duplicates(vaddrs, nfaults);

		mmget(svm_data->mm);
		mmap_write_lock(svm_data->mm);

		for (i = 0; i < nfaults; ++i) {
			if (is_page_present(svm_data, vaddrs[i])) {
				page = svm_perform_ptw(svm_data, vaddrs[i]);
				if (!page) {
					DEVERR(pdev->parent->dev_id,
					       "PTW for address translation failed");
					drop_page_fault(svm_data, vaddrs[i]);
				} else {
					dev_addr = pfn_to_dev_addr(svm_data,
								   page_to_pfn(
									   page));
					add_tlb_entry(svm_data,
						      vaddrs[i] & VADDR_MASK,
						      dev_addr);
				}
				vaddrs[i] = 0;
			}
		}

		nfaults = pack_array(vaddrs, nfaults);
		if (!nfaults) {
			mmap_write_unlock(svm_data->mm);
			mmput(svm_data->mm);
			break;
		}

		do {
			ncontiguous = 1;
			while (ncontiguous < nfaults &&
			       is_contiguous(vaddrs[ncontiguous],
					     vaddrs[ncontiguous - 1]))
				++ncontiguous;

			res = svm_migrate_to_device(pdev,
						    vaddrs[0] & VADDR_MASK,
						    ncontiguous, true);
			for (i = 0; i < ncontiguous; ++i)
				vaddrs[i] = 0;
			nfaults = pack_array(vaddrs, nfaults);
		} while (nfaults > 0);

		// make sure all writes to add entries are finished before retrieving more faults!
		wmb();

		mmap_write_unlock(svm_data->mm);
		mmput(svm_data->mm);

		// re-enable fault issuing
		writeq(MMU_ISSUE_FAULT_ENABLE,
		       &svm_data->mmu_regs->intr_enable);
		wmb();
	}

	writeq(MMU_INTR_ENABLE | MMU_ISSUE_FAULT_ENABLE,
	       &svm_data->mmu_regs->intr_enable);
	kfree(env);

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "finished handling IOMMU page faults");
}

/**
 * Invalidate TLB entries for a given virtual address range
 *
 * @param subscription registered MMU notifier
 * @param range address range to invalidate
 * @return always zero
 */
static int
svm_tlb_invalidate_range_start(struct mmu_notifier *subscription,
			       const struct mmu_notifier_range *range)
{
	int npages, inv_npages;
	unsigned long inv_start, inv_end;
	struct list_head intervals;
	struct vmem_interval_list_entry *entry;
	struct svm_mmu_notifier_env *env = container_of(
		subscription, struct svm_mmu_notifier_env, notifier);

	// MMU invalidation during migration is handled by respective functions
	if (range->event == MMU_NOTIFY_MIGRATE
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 14, 0)
	    && range->owner == env->svm_data->pdev
#else
	    && range->migrate_pgmap_owner == env->svm_data->pdev
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,14,0) */
	)
		goto skip_invalidation;

	// check whether region is present on device using the vmem list before invalidating TLB
	INIT_LIST_HEAD(&intervals);
	npages = (range->end - range->start) >> PAGE_SHIFT;
	if (search_vmem_intervals(env->svm_data, &intervals, range->start,
				  npages))
		DEVERR(env->svm_data->pdev->parent->dev_id,
		       "error during search for vmem intervals");
	while (!list_empty(&intervals)) {
		entry = list_first_entry(&intervals,
			struct vmem_interval_list_entry, list);
		inv_start = max(entry->interval_node->start, range->start);
		inv_end = min(entry->interval_node->last + 1, range->end);
		inv_npages = (inv_end - inv_start) >> PAGE_SHIFT;
		invalidate_tlb_range(env->svm_data, inv_start, inv_npages);
		wmb();
		remove_vmem_interval(env->svm_data, inv_start, inv_npages);

		list_del(&entry->list);
		kfree(entry);
	}

skip_invalidation:
	return 0;
}

/**
 * free the registered MMU notifier
 *
 * @param subscription MMU notifier to free
 */
static void svm_free_mmu_notifier(struct mmu_notifier *subscription)
{
	struct svm_mmu_notifier_env *env = container_of(
		subscription, struct svm_mmu_notifier_env, notifier);
	struct tlkm_pcie_svm_data *svm_data = env->svm_data;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "free MMU notifier");

	kfree(env);
	svm_data->notifier_env = NULL;
}

/*
 * functions for MMU notifier
 */
static struct mmu_notifier_ops svm_notifier_ops = {
	.invalidate_range_start = svm_tlb_invalidate_range_start,
	.free_notifier = svm_free_mmu_notifier,
};

/**
 * Register a MMU notifier to forward changes in the address map to the on-FPGA IOMMU
 *
 * @param pdev TLKM PCIe device struct
 * @param svm_data SVM data struct
 * @return error code in case of failure, zero when succeeding
 */
static int register_mmu_notifier(struct tlkm_pcie_device *pdev,
				 struct tlkm_pcie_svm_data *svm_data)
{
	int res;
	struct svm_mmu_notifier_env *notifier_env;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM, "register MMU notifier");

	notifier_env = kzalloc(sizeof(*svm_data->notifier_env), GFP_KERNEL);
	if (!notifier_env) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate memory for MMU notifier");
		res = -ENOMEM;
		goto fail_alloc;
	}

	notifier_env->svm_data = svm_data;
	notifier_env->notifier.ops = &svm_notifier_ops;
	res = mmu_notifier_register(&notifier_env->notifier, svm_data->mm);
	if (res) {
		DEVERR(pdev->parent->dev_id, "failed to register MMU notifier");
		goto fail_register;
	}
	svm_data->notifier_env = notifier_env;
	return 0;

fail_register:
	kfree(notifier_env);
fail_alloc:
	return res;
}

/**
 * Launch SVM functionality. Should be called by the runtime before starting
 * to schedule jobs to the PEs.
 *
 * @param inst TLKM device struct
 * @return Zero if SVM launched successfully, error code in case of failure
 */
int pcie_launch_svm(struct tlkm_device *inst)
{
	int res;
	struct tlkm_pcie_device *pdev = inst->private_data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	if (!svm_data) {
		DEVERR(pdev->parent->dev_id, "SVM not initialized");
		return -EFAULT;
	}

	// save task and mm struct information
	svm_data->task = current;
	svm_data->mm = current->mm;

	// clear TLB
	writeq(MMU_INVALIDATE_ALL, &svm_data->mmu_regs->cmd);

	// register MMU notifier
	if ((res = register_mmu_notifier(pdev, svm_data)))
		goto fail_mmunotifier;

	// activate MMU
	writeq(MMU_INTR_ENABLE | MMU_ISSUE_FAULT_ENABLE,
	       &svm_data->mmu_regs->intr_enable);
	writeq(MMU_ACTIVATE, &svm_data->mmu_regs->cmd);

	DEVLOG(inst->dev_id, TLKM_LF_SVM, "launched SVM successfully");

	return 0;

fail_mmunotifier:
	svm_data->task = NULL;
	svm_data->mm = NULL;
	return res;
}

/**
 * Tear down SVM functionality. Should be called by the runtime before exiting
 * the user program.
 *
 * @param inst TLKM device struct
 * @return Zero if SVM torn down successfully, error code in case of failure
 */
void pcie_teardown_svm(struct tlkm_device *inst)
{
	struct tlkm_pcie_device *pdev = inst->private_data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	writeq(0, &svm_data->mmu_regs->intr_enable);
	writeq(MMU_DEACTIVATE, &svm_data->mmu_regs->cmd);
	writeq(MMU_INVALIDATE_ALL, &svm_data->mmu_regs->cmd);

	flush_workqueue(svm_data->page_fault_queue);
	mmu_notifier_put(&svm_data->notifier_env->notifier);

	DEVLOG(inst->dev_id, TLKM_LF_SVM, "torn down SVM successfully");
}

/**
 * Interrupt service routing for handling IOMMU page fault interrupts
 *
 * @param irq IRQ number
 * @param data private data for service routine
 * @return IRQ_HANDLED
 */
irqreturn_t iommu_page_fault_handler(int irq, void *data)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	struct page_fault_work_env *env;

	// disable IOMMU page fault interrupt, but still allow enqueuing of
	// further faults to internal FIFO
	writeq(MMU_ISSUE_FAULT_ENABLE, &svm_data->mmu_regs->intr_enable);

	// schedule worker thread
	env = kmalloc(sizeof(*env), GFP_ATOMIC);
	if (!env) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate work struct for page fault handling");
		goto eof;
	}
	env->pdev = pdev;
	INIT_WORK(&env->work, handle_iommu_page_fault);
	if (!queue_work(svm_data->page_fault_queue, &env->work)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to schedule page fault worker thread");
		goto eof;
	}
eof:
	pdev->ack_register[0] = PAGE_FAULT_IRQ_NO;
	return IRQ_HANDLED;
}

/**
 * Interrupt service routing for handling C2H interrupts by the PageDMA core
 *
 * @param irq IRQ number
 * @param data private data for service routing
 * @return IRQ_HANDLED
 */
irqreturn_t svm_c2h_intr_handler(int irq, void *data)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	atomic_set(&svm_data->wait_flag_c2h_intr, 1);
	wake_up_interruptible(&svm_data->wait_queue_c2h_intr);
	pdev->ack_register[0] = C2H_IRQ_NO;
	return IRQ_HANDLED;
}

/**
 * Interrupt service routing for handling H2C interrupts by the PageDMA core
 *
 * @param irq IRQ number
 * @param data private data for service routing
 * @return IRQ_HANDLED
 */
irqreturn_t svm_h2c_intr_handler(int irq, void *data)
{
	struct tlkm_pcie_device *pdev = (struct tlkm_pcie_device *)data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	atomic_set(&svm_data->wait_flag_h2c_intr, 1);
	wake_up_interruptible(&svm_data->wait_queue_h2c_intr);
	pdev->ack_register[0] = H2C_IRQ_NO;
	return IRQ_HANDLED;
}

/**
 * Request page entries to represent device memory
 *
 * @param pdev TLKM PCIe device struct
 * @param svm_data SVM data struct
 * @return SUCCESS - 0, FAILURE - error code
 */
static int request_device_pages(struct tlkm_pcie_device *pdev,
			       struct tlkm_pcie_svm_data *svm_data)
{
	int res;
	void *res_ptr;
	struct resource *resource;
	struct dev_pagemap *pagemap;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "request device private page resources");

	pagemap = devm_kzalloc(&pdev->pdev->dev, sizeof(*pagemap), GFP_KERNEL);
	if (!pagemap) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate memory for device pagemap");
		res = -ENOMEM;
		goto fail_alloc;
	}

	// allocate memory region for device private pages
	resource = devm_request_free_mem_region(&pdev->pdev->dev,
						&iomem_resource, PHYS_MEM_SIZE);
	if (IS_ERR(resource)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to request memory region for device private pages");
		res = -ENOMEM;
		goto fail_region;
	}

	// prepare pagemap and remap pages as device private pages
	pagemap->type = MEMORY_DEVICE_PRIVATE;
	pagemap->range.start = resource->start;
	pagemap->range.end = resource->end;
	pagemap->nr_range = 1;
	pagemap->ops = &svm_pagemap_ops;
	pagemap->owner = pdev;

	res_ptr = devm_memremap_pages(&pdev->pdev->dev, pagemap);
	if (IS_ERR(res_ptr)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to remap device private pages");
		res = -ENOMEM;
		goto fail_remap;
	}

	svm_data->base_pfn = resource->start >> PAGE_SHIFT;
	return 0;

fail_remap:
	devm_release_resource(&pdev->pdev->dev, resource);
fail_region:
	devm_kfree(&pdev->pdev->dev, pagemap);
fail_alloc:
	return res;
}

/**
 * Initialize SVM functionality
 *
 * @param pdev TLKM PCIe device struct
 * @return Zero when succeeding, error code in case of failure
 */
int pcie_init_svm(struct tlkm_pcie_device *pdev)
{
	int res, mmu_irq_no, c2h_irq_no, h2c_irq_no;
	struct device_memory_block *mem_block;

	struct tlkm_pcie_svm_data *svm_data =
		devm_kzalloc(&pdev->pdev->dev, sizeof(*svm_data), GFP_KERNEL);
	if (!svm_data) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate SVM data struct");
		res = -ENOMEM;
		goto fail_alloc;
	}

	// initialize wait queues and atomics
	init_waitqueue_head(&svm_data->wait_queue_h2c_intr);
	init_waitqueue_head(&svm_data->wait_queue_c2h_intr);
	atomic_set(&svm_data->wait_flag_h2c_intr, 0);
	atomic_set(&svm_data->wait_flag_c2h_intr, 0);

	// initialize device memory allocator
	mutex_init(&svm_data->mem_block_mutex);
	mem_block = kmalloc(sizeof(*mem_block), GFP_KERNEL);
	if (!mem_block) {
		DEVERR(pdev->parent->dev_id,
		       "could not allocate struct for initial device memory block");
		res = -ENOMEM;
		goto fail_alloc_memblock;
	}
	mem_block->base_addr = 0;
	mem_block->size = PHYS_MEM_SIZE;
	INIT_LIST_HEAD(&svm_data->free_mem_blocks);
	list_add(&mem_block->list, &svm_data->free_mem_blocks);
	svm_data->vmem_intervals = RB_ROOT_CACHED;

	// initialize work queues
	svm_data->page_fault_queue =
		alloc_workqueue(TLKM_PCI_NAME, WQ_UNBOUND | WQ_MEM_RECLAIM, 0);
	if (!svm_data->page_fault_queue) {
		DEVERR(pdev->parent->dev_id,
		       "could not allocate work queue for page fault handling");
		res = -EFAULT;
		goto fail_workqueue_pagefault;
	}
	svm_data->dev_mem_free_queue =
		alloc_workqueue(TLKM_PCI_NAME, WQ_UNBOUND | WQ_MEM_RECLAIM, 0);
	if (!svm_data->dev_mem_free_queue) {
		DEVERR(pdev->parent->dev_id,
		       "could not allocate work queue for freeing device memory");
		res = -EFAULT;
		goto fail_workqueue_devmemfree;
	}

	// register DMA interrupts
	c2h_irq_no = pci_irq_vector(pdev->pdev, C2H_IRQ_NO);
	res = request_irq(c2h_irq_no, svm_c2h_intr_handler, IRQF_EARLY_RESUME,
			  TLKM_PCI_NAME, (void *)pdev);
	if (res) {
		DEVERR(pdev->parent->dev_id, "could not request C2H interrupt");
		goto fail_c2hintr;
	}
	h2c_irq_no = pci_irq_vector(pdev->pdev, H2C_IRQ_NO);
	res = request_irq(h2c_irq_no, svm_h2c_intr_handler, IRQF_EARLY_RESUME,
			  TLKM_PCI_NAME, (void *)pdev);
	if (res) {
		DEVERR(pdev->parent->dev_id, "could not request H2C interrupt");
		goto fail_h2cintr;
	}

	// register IOMMU page fault interrupt handler
	mmu_irq_no = pci_irq_vector(pdev->pdev, PAGE_FAULT_IRQ_NO);
	res = request_irq(mmu_irq_no, iommu_page_fault_handler,
			  IRQF_EARLY_RESUME, TLKM_PCI_NAME, (void *)pdev);
	if (res) {
		DEVERR(pdev->parent->dev_id,
		       "could not request IOMMU page fault IRQ");
		goto fail_mmuirq;
	}

	res = request_device_pages(pdev, svm_data);
	if (res) {
		goto fail_reqpages;
	}

	// save pointer to MMU and DMA registers for easier use later on
	svm_data->mmu_regs =
		(struct mmu_regs *)(pdev->parent->mmap.plat +
				    tlkm_status_get_component_base(
					    pdev->parent,
					    "PLATFORM_COMPONENT_MMU"));
	svm_data->dma_regs =
		(struct page_dma_regs *)(pdev->parent->mmap.plat +
					 tlkm_status_get_component_base(
						 pdev->parent,
						 "PLATFORM_COMPONENT_DMA0"));
	if (readq(&svm_data->dma_regs->id) == NETWORK_PAGE_DMA_ID) {
		DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
		       "PageDMA capable of network page migrations");
		svm_data->network_dma_enabled = true;
		svm_data->mac_addr = readq(&svm_data->dma_regs->own_mac);
	}

	if (pci_resource_len(pdev->pdev, 2) >= PHYS_MEM_SIZE)
		svm_data->rdma_bar = pci_resource_start(pdev->pdev, 2);

	svm_data->pdev = pdev;
	pdev->svm_data = svm_data;

	return 0;

fail_reqpages:
	free_irq(mmu_irq_no, (void *)pdev);
fail_mmuirq:
	free_irq(h2c_irq_no, (void *)pdev);
fail_h2cintr:
	free_irq(c2h_irq_no, (void *)pdev);
fail_c2hintr:
	destroy_workqueue(svm_data->dev_mem_free_queue);
fail_workqueue_devmemfree:
	destroy_workqueue(svm_data->page_fault_queue);
fail_workqueue_pagefault:
	kfree(mem_block);
fail_alloc_memblock:
	devm_kfree(&pdev->pdev->dev, svm_data);
fail_alloc:
	return res;
}

/**
 * De-initialize SVM functionality
 *
 * @param pdev TLKM PCIe device struct
 */
void pcie_exit_svm(struct tlkm_pcie_device *pdev)
{
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	// do not flush this queue before exiting
	flush_workqueue(svm_data->dev_mem_free_queue);

	free_irq(pci_irq_vector(pdev->pdev, PAGE_FAULT_IRQ_NO), (void *)pdev);
	free_irq(pci_irq_vector(pdev->pdev, H2C_IRQ_NO), (void *)pdev);
	free_irq(pci_irq_vector(pdev->pdev, C2H_IRQ_NO), (void *)pdev);

	destroy_workqueue(svm_data->page_fault_queue);
	destroy_workqueue(svm_data->dev_mem_free_queue);

	pdev->svm_data = NULL;
}

#endif /* defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */