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
 * Initiate a card-to-host (C2H) DMA transfer using the PageDMA core
 *
 * @param svm_data SVM data struct
 * @param host_addr DMA address in host memory (destination address)
 * @param dev_addr address in device memory (source address)
 * @param npages number of pages to transfer
 */
static void init_c2h_dma(struct tlkm_pcie_svm_data *svm_data,
			 dma_addr_t host_addr, uint64_t dev_addr, int npages)
{
	uint64_t npages_cmd, wval;
	struct page_dma_regs *dma_regs = svm_data->dma_regs;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "initiate C2H DMA: host addr = %llx, device addr = %llx, length = %0d",
	       host_addr, dev_addr, npages);

	while (npages) {
		writeq(dev_addr, &dma_regs->c2h_src_addr);
		writeq(host_addr, &dma_regs->c2h_dst_addr);
		npages_cmd = (npages > PAGE_DMA_MAX_NPAGES) ?
				     PAGE_DMA_MAX_NPAGES :
					   npages;
		wval = npages_cmd | PAGE_DMA_CMD_START;
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
 */
static void init_h2c_dma(struct tlkm_pcie_svm_data *svm_data,
			 dma_addr_t host_addr, uint64_t dev_addr, int npages,
			 int clear)
{
	uint64_t npages_cmd, wval;
	struct page_dma_regs *dma_regs = svm_data->dma_regs;

	DEVLOG(svm_data->pdev->parent->dev_id, TLKM_LF_SVM,
	       "initiate H2C DMA: host addr = %llx, device addr = %llx, length = %0d, clear = %0d",
	       host_addr, dev_addr, npages, clear);

	while (npages) {
		npages_cmd = (npages > PAGE_DMA_MAX_NPAGES) ?
				     PAGE_DMA_MAX_NPAGES :
					   npages;
		wval = npages_cmd | PAGE_DMA_CMD_START;
		if (clear)
			wval |= PAGE_DMA_CMD_CLEAR;
		else
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
		list_add(&new_mem_block->list, &svm_data->free_mem_blocks);
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
					  struct tlkm_pcie_svm_data *svm_data,
					  uint64_t dev_addr, uint64_t size)
{
	struct dev_mem_free_work_env *env = kmalloc(sizeof(*env), GFP_KERNEL);
	env->pdev = pdev;
	env->dev_addr = dev_addr;
	env->size = size;
	INIT_WORK(&env->work, handle_device_memory_free);
	return queue_work(svm_data->dev_mem_free_queue, &env->work);
}

/**
 * Free a device private page by re-adding it to list of free pages
 * Attention: This function only frees the page entry, the actual memory
 * allocation must be freed separately
 *
 * @param pdev TLKM PCIe device struct
 * @param page page to free
 */
static void free_device_page(struct tlkm_pcie_device *pdev, struct page *page)
{
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	spin_lock(&svm_data->page_lock);
	page->zone_device_data = svm_data->free_pages;
	svm_data->free_pages = page;
	spin_unlock(&svm_data->page_lock);
}

/**
 * Free a device page and the corresponding memory allocation. This function
 * is only called by the OS kernel.
 *
 * @param page page to free
 */
static void kernel_page_free(struct page *page)
{
	struct pci_dev *pci_dev = page->pgmap->owner;
	struct tlkm_pcie_device *pdev = dev_get_drvdata(&pci_dev->dev);
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;
	uint64_t paddr = (uint64_t)page->zone_device_data;

	free_device_page(pdev, page);
	if (!queue_dev_mem_free_work(pdev, svm_data, paddr, PAGE_SIZE)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to schedule worker thread for freeing device memory");
	}
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

	struct pci_dev *pci_dev = vmf->page->pgmap->owner;
	struct tlkm_pcie_device *pdev = dev_get_drvdata(&pci_dev->dev);
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "handle CPU page fault: vaddr = %lx", vmf->address);

	// invalidate TLB entry and check for active access
	writeq(vmf->address, &svm_data->mmu_regs->vaddr);
	writeq(MMU_INVALIDATE_ENTRY, &svm_data->mmu_regs->cmd);
	while (readq(&svm_data->mmu_regs->status) &
	       MMU_STATUS_MEM_ACCESS_ACTIVE)
		;

	// populate migrate_vma struct and setup migration
	migrate.vma = vmf->vma;
	migrate.dst = &dst;
	migrate.src = &src;
	migrate.start = vmf->address;
	migrate.end = vmf->address + PAGE_SIZE;
	migrate.pgmap_owner = pci_dev;
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
	dst = migrate_pfn(page_to_pfn(dst_page)) | MIGRATE_PFN_LOCKED;

	// DMA transfer
	dma_addr = dma_map_page(&pci_dev->dev, dst_page, 0, PAGE_SIZE,
				DMA_FROM_DEVICE);
	if (dma_mapping_error(&pci_dev->dev, dma_addr)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to map page for DMA during back migration after CPU page fault");
		goto fail_map;
	}

	src_addr = (uint64_t)src_page->zone_device_data;
	init_c2h_dma(svm_data, dma_addr, src_addr, 1);

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
 * Request struct pages from the OS to use as device private pages
 * We always request 128 MB bunches as this is the standard size Linux allocates anyways
 *
 * @param pdev TLKM PCIe device struct
 * @param svm_data SVM data struct
 * @return error code in case of failure, zero when succeeding
 */
static int request_mem_section(struct tlkm_pcie_device *pdev,
			       struct tlkm_pcie_svm_data *svm_data)
{
	int res, i;
	void *res_ptr;
	struct page *page;
	struct svm_mem_section *section;

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "request device private page resources");

	section = devm_kzalloc(&pdev->pdev->dev, sizeof(*section), GFP_KERNEL);
	if (!section) {
		DEVERR(pdev->parent->dev_id,
		       "failed to allocate SVM memory section struct");
		res = -ENOMEM;
		goto fail_alloc;
	}

	// allocate memory region for device private pages
	section->resource = devm_request_free_mem_region(
		&pdev->pdev->dev, &iomem_resource, MEM_SECTION_SIZE);
	if (IS_ERR(section->resource)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to request memory region for device private pages");
		res = -ENOMEM;
		goto fail_region;
	}

	// prepare pagemap and remap pages as device private pages
	section->pagemap.type = MEMORY_DEVICE_PRIVATE;
	section->pagemap.range.start = section->resource->start;
	section->pagemap.range.end = section->resource->end;
	section->pagemap.nr_range = 1;
	section->pagemap.ops = &svm_pagemap_ops;
	section->pagemap.owner = pdev->pdev;

	res_ptr = devm_memremap_pages(&pdev->pdev->dev, &section->pagemap);
	if (IS_ERR(res_ptr)) {
		DEVERR(pdev->parent->dev_id,
		       "failed to remap device private pages");
		res = -ENOMEM;
		goto fail_remap;
	}

	// add section to list
	mutex_lock(&svm_data->sections_mutex);
	list_add(&section->list, &svm_data->mem_sections);
	mutex_unlock(&svm_data->sections_mutex);

	// add allocated pages to list of free pages
	spin_lock(&svm_data->page_lock);
	page = pfn_to_page(section->resource->start >> PAGE_SHIFT);
	for (i = 0; i < MEM_SECTION_NPAGES; ++i) {
		page->zone_device_data = svm_data->free_pages;
		svm_data->free_pages = page;
		++page;
	}
	spin_unlock(&svm_data->page_lock);

	return 0;

fail_remap:
	devm_release_resource(&pdev->pdev->dev, section->resource);
fail_region:
	devm_kfree(&pdev->pdev->dev, section);
fail_alloc:
	return res;
}

/**
 * Allocate a device private page struct. The actual allocation of a physical
 * section in device memory is handled separately.
 *
 * @param svm_data SVM data struct
 * @return pointer to allocated page struct, or NULL in case of failure
 */
static struct page *alloc_device_page(struct tlkm_pcie_svm_data *svm_data)
{
	int res;
	struct tlkm_pcie_device *pdev = svm_data->pdev;
	struct page *page;

	spin_lock(&svm_data->page_lock);
	if (!svm_data->free_pages) {
		spin_unlock(&svm_data->page_lock);
		res = request_mem_section(pdev, svm_data);
		if (res) {
			DEVERR(pdev->parent->dev_id,
			       "failed to allocate additional device private pages");
			return NULL;
		}
		spin_lock(&svm_data->page_lock);
	}

	page = svm_data->free_pages;
	svm_data->free_pages = page->zone_device_data;
	page->zone_device_data = NULL;
	spin_unlock(&svm_data->page_lock);
	return page;
}

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
	return (addr == last + PAGE_SIZE);
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
 * Migrate multiple pages with contiguous virtual addresses from host to device
 * memory
 *
 * @param pdev TLKM PCIe device struct
 * @param vaddr virtual address of the first page
 * @param npages number of contiguous pages
 * @param drop if true: send drop commands to IOMMU for failed migrations
 * @return Zero when succeeding, error code in case of failure
 */
static int svm_migrate_to_device(struct tlkm_pcie_device *pdev, uint64_t vaddr,
				 int npages, int drop)
{
	int res, i, j, ncontiguous, cmd_cnt, clear;
	uint64_t dev_base_addr;
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
	mmget(svm_data->mm);
	mmap_read_lock(svm_data->mm);
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
	migrate.pgmap_owner = pdev->pdev;
	migrate.flags = MIGRATE_VMA_SELECT_SYSTEM;
	res = migrate_vma_setup(&migrate);
	if (res < 0) {
		DEVERR(pdev->parent->dev_id,
		       "failed to setup buffer migration");
		goto fail_setup;
	}
	if (!migrate.cpages) {
		DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
		       "no pages to migrate");
		goto skip_copy;
	}

	// allocate device private pages
	for (i = 0; i < npages; ++i) {
		if (migrate.src[i] & MIGRATE_PFN_MIGRATE) {
			src_pages[i] = migrate_pfn_to_page(migrate.src[i]);
			dst_pages[i] = alloc_device_page(svm_data);
			if (!dst_pages[i]) {
				DEVERR(pdev->parent->dev_id,
				       "failed to allocate device page");
				res = -ENOMEM;
				goto fail_allocpage;
			}
		} else {
			continue;
		}
		get_page(dst_pages[i]);
		lock_page(dst_pages[i]);
		migrate.dst[i] = migrate_pfn(page_to_pfn(dst_pages[i])) |
				 MIGRATE_PFN_LOCKED;

		// map source pages for DMA access
		if (src_pages[i]) {
			dma_addrs[i] =
				dma_map_page(&pdev->pdev->dev, src_pages[i], 0,
					     PAGE_SIZE, DMA_TO_DEVICE);
			if (dma_mapping_error(&pdev->pdev->dev, dma_addrs[i])) {
				DEVWRN(pdev->parent->dev_id,
				       "failed to map page for DMA");
				unlock_page(dst_pages[i]);
				put_page(dst_pages[i]);
				free_device_page(pdev, dst_pages[i]);
				dst_pages[i] = NULL;
				migrate.dst[i] = 0;
				dma_addrs[i] = 0;
			}
		}
	}

	i = 0;
	while (i < npages) {
		if (!migrate.dst[i]) {
			++i;
			continue;
		}

		// find virtual contiguous region to allocate memory
		ncontiguous = 1;
		while (i + ncontiguous < npages && migrate.dst[i + ncontiguous])
			++ncontiguous;

		dev_base_addr = allocate_device_memory(svm_data,
						       ncontiguous * PAGE_SIZE);

		if (dev_base_addr == -1) {
			DEVERR(pdev->parent->dev_id,
			       "failed to allocate memory on device");

			// free previous allocations
			for (j = 0; j < i; ++j) {
				if (!queue_dev_mem_free_work(
					    pdev, svm_data,
					    (uint64_t)dst_pages[j]
						    ->zone_device_data,
					    PAGE_SIZE))
					DEVERR(pdev->parent->dev_id,
					       "failed to queue work struct for freeing device memory region");
			}

			res = -ENOMEM;
			goto fail_allocmem;
		}

		// save physical address of page in device memory
		for (j = 0; j < ncontiguous; ++j)
			dst_pages[i + j]->zone_device_data =
				(void *)(dev_base_addr + j * PAGE_SIZE);

		i += ncontiguous;
	}

	i = 0;
	cmd_cnt = 0;
	while (i < npages) {
		if (!migrate.dst[i]) {
			++i;
			continue;
		}

		// find physical contiguous region on host side
		// (always contiguous on device side due to allocation scheme)
		ncontiguous = 1;
		if (src_pages[i]) {
			clear = 0;
			while (i + ncontiguous < npages &&
			       ncontiguous < PAGE_DMA_MAX_NPAGES &&
			       src_pages[i + ncontiguous] &&
			       migrate.dst[i + ncontiguous]) {
				if (is_contiguous(
					    dma_addrs[i + ncontiguous],
					    dma_addrs[i + ncontiguous - 1]))
					++ncontiguous;
				else
					break;
			}
		} else {
			clear = 1;
			while (i + ncontiguous < npages &&
			       ncontiguous < PAGE_DMA_MAX_NPAGES &&
			       !src_pages[i + ncontiguous] &&
			       migrate.dst[i + ncontiguous])
				++ncontiguous;
		}

		// check whether PageDMA can accept further commands to prevent
		// deadlock on PCIe bus
		if (cmd_cnt >= 32 &&
		    readq(&svm_data->dma_regs->h2c_status_ctrl) &
			    PAGE_DMA_STAT_FIFO_FULL) {
			wait_for_h2c_intr(svm_data);
			cmd_cnt = 0;
		}
		init_h2c_dma(svm_data, dma_addrs[i],
			     (uint64_t)dst_pages[i]->zone_device_data,
			     ncontiguous, clear);
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
			if (dst_pages[i]) {
				unlock_page(dst_pages[i]);
				put_page(dst_pages[i]);
				free_device_page(pdev, dst_pages[i]);
				if (!queue_dev_mem_free_work(
					    pdev, svm_data,
					    (uint64_t)dst_pages[i]
						    ->zone_device_data,
					    PAGE_SIZE))
					DEVERR(pdev->parent->dev_id,
					       "failed to queue work struct for freeing device memory");
			}
		}
	}

skip_copy:
	// add TLB entries
	i = 0;
	while (i < npages) {
		if (!(migrate.src[i] & MIGRATE_PFN_MIGRATE)) {
			if (drop)
				drop_page_fault(svm_data,
						vaddr + i * PAGE_SIZE);
			++i;
			continue;
		}
		ncontiguous = 1;
		while (i + ncontiguous < npages &&
		       is_contiguous((uint64_t)(dst_pages[i + ncontiguous]
							->zone_device_data),
				     (uint64_t)(dst_pages[i + ncontiguous - 1]
							->zone_device_data)) &&
		       ncontiguous < MMU_MAX_MAPPING_LENGTH &&
		       (migrate.src[i + ncontiguous] & MIGRATE_PFN_MIGRATE)) {
			++ncontiguous;
		}
		// only use arbitrary length TLB mappings for contiguous regions
		// to save resources
		if (ncontiguous >= 64) {
			add_al_tlb_entry(
				svm_data, vaddr + i * PAGE_SIZE,
				(uint64_t)(dst_pages[i]->zone_device_data),
				ncontiguous);
		} else {
			for (j = i; j < (i + ncontiguous); ++j)
				add_tlb_entry(
					svm_data, vaddr + j * PAGE_SIZE,
					(uint64_t)(dst_pages[j]
							   ->zone_device_data));
		}
		i += ncontiguous;
	}

	migrate_vma_finalize(&migrate);
	mmap_read_unlock(svm_data->mm);
	mmput(svm_data->mm);
	kfree(dma_addrs);
	kfree(dst_pages);
	kfree(src_pages);
	kfree(migrate.dst);
	kfree(migrate.src);

	DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
	       "migration to device memory complete");

	return 0;

fail_dma:
	for (i = 0; i < npages; ++i) {
		if (dst_pages[i]) {
			if (!queue_dev_mem_free_work(
				    pdev, svm_data,
				    (uint64_t)dst_pages[i]->zone_device_data,
				    PAGE_SIZE))
				DEVERR(pdev->parent->dev_id,
				       "failed to queue work struct for freeing device memory");
		}
	}
fail_allocmem:
	for (i = 0; i < npages; ++i) {
		if (dma_addrs[i])
			dma_unmap_page(&pdev->pdev->dev, dma_addrs[i],
				       PAGE_SIZE, DMA_TO_DEVICE);
	}
fail_allocpage:
	for (i = 0; i < npages; ++i) {
		if (dst_pages[i]) {
			unlock_page(dst_pages[i]);
			put_page(dst_pages[i]);
			free_device_page(pdev, dst_pages[i]);
		}
		migrate.dst[i] = 0;
	}
	migrate_vma_finalize(&migrate);
fail_setup:
fail_vma:
	mmap_read_unlock(svm_data->mm);
	mmput(svm_data->mm);
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
 * Execute user managed migration of a memory region from host to device memory
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
		res = -EFAULT;
		goto fail_nosvm;
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

	res = svm_migrate_to_device(pdev, va_start, npages, 0);
	if (res) {
		DEVERR(inst->dev_id,
		       "failed to migrate memory region to device");
		goto fail_migrate;
	}

	return 0;

fail_migrate:
fail_nosvm:
	return res;
}

/**
 * Execute user managed migration of a memory region form device to host memory
 *
 * @param inst TLKM device struct
 * @param vaddr virtual base address of the memory region
 * @param size size of the memory region in bytes
 * @return Zero when succeeding, error code in case of failure
 */
int pcie_svm_user_managed_migration_to_ram(struct tlkm_device *inst,
					   uint64_t vaddr, uint64_t size)
{
	int res, i, npages, ncontiguous, cmd_cnt;
	uint64_t va_start, va_end;
	dma_addr_t *dma_addrs;
	struct page **src_pages, **dst_pages;
	struct migrate_vma migrate;
	struct vm_area_struct *vma;
	struct tlkm_pcie_device *pdev = inst->private_data;
	struct tlkm_pcie_svm_data *svm_data = pdev->svm_data;

	if (!svm_data) {
		DEVERR(pdev->parent->dev_id, "SVM not supported by bitstream");
		res = -EFAULT;
		goto fail_nosvm;
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
	mmget(svm_data->mm);
	mmap_read_lock(svm_data->mm);
	vma = find_vma_intersection(svm_data->mm, va_start, va_end);
	if (!vma) {
		DEVERR(pdev->parent->dev_id, "could not find matching VMA");
		res = -EFAULT;
		goto fail_vma;
	}

	// deactivate MMU, invalidate all entries, and wait for active memory
	// accesses to finish
	writeq(MMU_DEACTIVATE, &svm_data->mmu_regs->cmd);
	for (i = 0; i < npages; ++i) {
		writeq(va_start + i * PAGE_SIZE, &svm_data->mmu_regs->vaddr);
		writeq(MMU_INVALIDATE_ENTRY, &svm_data->mmu_regs->cmd);
	}
	while (readq(&svm_data->mmu_regs->status) & MMU_STATUS_ANY_MEM_ACCESS)
		;

	// setup migration
	migrate.start = va_start;
	migrate.end = va_end;
	migrate.vma = vma;
	migrate.pgmap_owner = pdev->pdev;
	migrate.flags = MIGRATE_VMA_SELECT_DEVICE_PRIVATE;
	res = migrate_vma_setup(&migrate);
	if (res < 0) {
		DEVERR(pdev->parent->dev_id, "failed to setup migration");
		goto fail_setup;
	}
	if (!migrate.cpages) {
		DEVLOG(pdev->parent->dev_id, TLKM_LF_SVM,
		       "no pages to migrate");
		goto skip_copy;
	}

	// allocate pages in host memory and create DMA mappings
	for (i = 0; i < npages; ++i) {
		if (migrate.src[i] & MIGRATE_PFN_MIGRATE) {
			src_pages[i] = migrate_pfn_to_page(migrate.src[i]);
			dst_pages[i] = alloc_page_vma(GFP_HIGHUSER, vma,
						      va_start + i + PAGE_SIZE);
			if (!dst_pages[i]) {
				DEVERR(pdev->parent->dev_id,
				       "failed to allocate page on host for migration");
				res = -ENOMEM;
				goto fail_allocpage;
			}
			lock_page(dst_pages[i]);
			migrate.dst[i] =
				migrate_pfn(page_to_pfn(dst_pages[i])) |
				MIGRATE_PFN_LOCKED;
			dma_addrs[i] =
				dma_map_page(&pdev->pdev->dev, dst_pages[i], 0,
					     PAGE_SIZE, DMA_FROM_DEVICE);
			if (dma_mapping_error(&pdev->pdev->dev, dma_addrs[i])) {
				DEVWRN(pdev->parent->dev_id,
				       "failed to map page for DMA");
				unlock_page(dst_pages[i]);
				__free_page(dst_pages[i]);
				dst_pages[i] = NULL;
				migrate.dst[i] = 0;
				dma_addrs[i] = 0;
			}
		}
	}

	i = 0;
	cmd_cnt = 0;
	while (i < npages) {
		if (!migrate.dst[i]) {
			++i;
			continue;
		}

		// find physical contiguous regions on host and device side
		ncontiguous = 1;
		while (i + ncontiguous < npages &&
		       ncontiguous < PAGE_DMA_MAX_NPAGES &&
		       migrate.dst[i + ncontiguous]) {
			if (is_contiguous(dma_addrs[i + ncontiguous],
					  dma_addrs[i + ncontiguous - 1]) &&
			    is_contiguous(
				    (uint64_t)src_pages[i + ncontiguous]
					    ->zone_device_data,
				    (uint64_t)src_pages[i + ncontiguous - 1]
					    ->zone_device_data))
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
		init_c2h_dma(svm_data, dma_addrs[i],
			     (uint64_t)src_pages[i]->zone_device_data,
			     ncontiguous);
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
			if (dst_pages[i]) {
				unlock_page(dst_pages[i]);
				__free_page(dst_pages[i]);
			}
		}
	}

skip_copy:
	migrate_vma_finalize(&migrate);

	writeq(MMU_ACTIVATE, &svm_data->mmu_regs->cmd);
	mmap_read_unlock(svm_data->mm);
	mmput(svm_data->mm);
	kfree(dma_addrs);
	kfree(dst_pages);
	kfree(src_pages);
	kfree(migrate.dst);
	kfree(migrate.src);

	return 0;

fail_dma:
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
fail_setup:
	writeq(MMU_ACTIVATE, &svm_data->mmu_regs->cmd);
fail_vma:
	mmap_read_unlock(svm_data->mm);
	mmput(svm_data->mm);
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
fail_nosvm:
	return res;
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
 * Compare two uint64_t, used for sort function
 *
 * @param p1 first number
 * @param p2 second number
 * @return 1 if p1 > p2, -1 if p1 < p2, 0 if p1 == p2
 */
static int svm_cmp_addr(const void *p1, const void *p2)
{
	const uint64_t *addr_1 = p1;
	const uint64_t *addr_2 = p2;
	return (*addr_1 > *addr_2) - (*addr_1 < *addr_2);
}

/**
 * remove duplicates in a sorted array
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
		if (array[i] == array[i - 1]) {
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
 * Handle device page faults by the on-FPGA IOMMU
 *
 * @param work work struct containing required data for the cmwq worker thread
 */
static void handle_iommu_page_fault(struct work_struct *work)
{
	int res, i, nfaults, ncontiguous;
	uint64_t rval, vaddrs[MAX_NUM_FAULTS];
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
			if (!(rval & VALID_ADDR_MASK))
				break;
			vaddrs[nfaults] = rval & VADDR_MASK;
			++nfaults;
		}

		if (!nfaults)
			break;

		sort(vaddrs, nfaults, sizeof(*vaddrs), svm_cmp_addr, NULL);
		nfaults = remove_duplicates(vaddrs, nfaults);

		for (i = 0; i < nfaults; ++i) {
			page = svm_perform_ptw(svm_data, vaddrs[i]);
			if (page) {
				add_tlb_entry(svm_data, vaddrs[i],
					      (uint64_t)page->zone_device_data);
				vaddrs[i] = 0;
			}
		}

		nfaults = pack_array(vaddrs, nfaults);
		if (!nfaults)
			break;

		do {
			ncontiguous = 1;
			while (ncontiguous < nfaults &&
			       is_contiguous(vaddrs[ncontiguous],
					     vaddrs[ncontiguous - 1]))
				++ncontiguous;

			res = svm_migrate_to_device(pdev, vaddrs[0],
						    ncontiguous, 1);
			if (res) {
				DEVERR(pdev->parent->dev_id,
				       "failed to migrate pages to device memory during page fault handling");
				for (i = 0; i < ncontiguous; ++i)
					drop_page_fault(svm_data, vaddrs[i]);
			}
			for (i = 0; i < ncontiguous; ++i) {
				vaddrs[i] = 0;
			}
			nfaults = pack_array(vaddrs, nfaults);
		} while (nfaults > 0);

		// make sure all writes to add entries are finished before retrieving more faults!
		wmb();

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
	unsigned long addr;
	struct svm_mmu_notifier_env *env = container_of(
		subscription, struct svm_mmu_notifier_env, notifier);

	// MMU invalidation during migration is handled by respective functions
	if (range->event == MMU_NOTIFY_MIGRATE
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 14, 0)
	    && range->owner == env->svm_data->pdev->pdev
#else
	    && range->migrate_pgmap_owner == env->svm_data->pdev->pdev
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,14,0) */
	)
		goto skip_invalidation;

	for (addr = range->start; addr < range->end; addr += PAGE_SIZE) {
		writeq(addr, &env->svm_data->mmu_regs->vaddr);
		writeq(MMU_INVALIDATE_ENTRY, &env->svm_data->mmu_regs->cmd);
	}
	wmb();

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

	mmu_notifier_put(&svm_data->notifier_env->notifier);

	flush_workqueue(svm_data->page_fault_queue);

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

	// disable IOMMU page fault interrupt
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
	// FIXME what memory size?
	mem_block->size = 4UL << 30;
	INIT_LIST_HEAD(&svm_data->free_mem_blocks);
	list_add(&mem_block->list, &svm_data->free_mem_blocks);

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

	mutex_init(&svm_data->sections_mutex);
	spin_lock_init(&svm_data->page_lock);
	INIT_LIST_HEAD(&svm_data->mem_sections);
	res = request_mem_section(pdev, svm_data);
	if (res) {
		goto fail_memregion;
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
	svm_data->pdev = pdev;
	pdev->svm_data = svm_data;

	return 0;

fail_memregion:
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

	spin_lock(&svm_data->page_lock);
	svm_data->free_pages = NULL;
	spin_unlock(&svm_data->page_lock);

	pdev->svm_data = NULL;
}

#endif /* defined(EN_SVM) && LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */