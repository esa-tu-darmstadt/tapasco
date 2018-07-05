//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
 *  @file	zynq_ioctl.c
 *  @brief	Zynq-specific implementation of ioctl interface.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <linux/uaccess.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/gfp.h>

#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_device_ioctl_cmds.h"
#include "zynq_device.h"
#include "zynq_dmamgmt.h"

static inline
long zynq_ioctl_info(struct tlkm_device *inst, struct tlkm_device_info *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline
long zynq_ioctl_alloc(struct tlkm_device *inst, struct tlkm_mm_cmd *cmd)
{
	struct dma_buf_t *dmab;
	dma_addr_t dma_addr;
	if (cmd->sz == 0 || cmd->sz > (1 << 27)) {
		DEVWRN(inst->dev_id, "invalid length: %zu bytes", cmd->sz);
		return -EINVAL;
	}
	if (cmd->dev_addr >= 0 && (dmab = zynq_dmamgmt_get(cmd->dev_addr))) {
		DEVWRN(inst->dev_id, "buffer with id %ld is already allocated, aborting", (long)cmd->dev_addr);
		return -EINVAL;
	}

	dma_addr = zynq_dmamgmt_alloc(cmd->sz, NULL);
	if (! dma_addr) {
		DEVWRN(inst->dev_id, "allocation failed: len = %zu", cmd->sz);
		return -ENOMEM;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "alloc: len = %zu, dma = %pad", cmd->sz, &dma_addr);
	cmd->dev_addr = dma_addr;
	tlkm_perfc_total_alloced_mem_add(inst->dev_id, cmd->sz);
	return 0;
}

static inline
long zynq_ioctl_free(struct tlkm_device *inst, struct tlkm_mm_cmd *cmd)
{
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "free: len = %zu, dma = %pad", cmd->sz, &cmd->dev_addr);
	if (cmd->dev_addr >= 0) {
		zynq_dmamgmt_dealloc_dma(cmd->dev_addr);
		cmd->dev_addr = -1;
		tlkm_perfc_total_freed_mem_add(inst->dev_id, cmd->sz);
	}
	return 0;
}

static inline
long zynq_ioctl_copyto(struct tlkm_device *inst, struct tlkm_copy_cmd *cmd)
{
	struct dma_buf_t *dmab;
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyto: len = %zu, dma = %pad, p = 0x%px",
			cmd->length, &cmd->dev_addr, cmd->user_addr);
	// allocate, if necessary
	if (cmd->dev_addr < 0 || ! (dmab = zynq_dmamgmt_get(zynq_dmamgmt_get_id(cmd->dev_addr)))) {
		int ret;
		struct tlkm_mm_cmd mm_cmd = { .sz = cmd->length, };
		mm_cmd.dev_addr = -1;
		DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "allocating %zu bytes for transfer", cmd->length);
		ret = zynq_ioctl_alloc(inst, &mm_cmd);
		cmd->dev_addr = mm_cmd.dev_addr;
		if (ret) return ret;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "cmd->dev_addr = %pad", &cmd->dev_addr);
	dmab = zynq_dmamgmt_get(zynq_dmamgmt_get_id(cmd->dev_addr));
	if (! dmab || ! dmab->kvirt_addr) {
		DEVERR(inst->dev_id, "something went wrong in the allocation");
		return -ENOMEM;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "dmab->kvirt_addr = 0x%px, dmab->dma_addr = %pad",
			dmab->kvirt_addr, &dmab->dma_addr);
	if (copy_from_user(dmab->kvirt_addr, (void __user *) cmd->user_addr, cmd->length)) {
		DEVWRN(inst->dev_id, "could not copy all bytes from user space");
		return -EACCES;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyto finished successfully");
	tlkm_perfc_total_usr2dev_transfers_add(inst->dev_id, cmd->length);
	return 0;
}

static inline
long zynq_ioctl_copyfrom(struct tlkm_device *inst, struct tlkm_copy_cmd *cmd)
{
	struct dma_buf_t *dmab;
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "copyfrom: len = %zu, dma = %pad, p = 0x%px",
			cmd->length, &cmd->dev_addr, cmd->user_addr);
	dmab = zynq_dmamgmt_get(zynq_dmamgmt_get_id(cmd->dev_addr));
	if (! dmab || ! dmab->kvirt_addr) {
		DEVERR(inst->dev_id, "could not get dma buffer with dma = %pad", &cmd->dev_addr);
			return -EINVAL;
	}
	if (copy_to_user((void __user *) cmd->user_addr, dmab->kvirt_addr, cmd->length)) {
		DEVWRN(inst->dev_id, "could not copy all bytes from user space");
		return -EACCES;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyfrom finished successfully");
	tlkm_perfc_total_dev2usr_transfers_add(inst->dev_id, cmd->length);
	return 0;
}

static inline
long zynq_ioctl_alloc_copyto(struct tlkm_device *inst, struct tlkm_bulk_cmd *cmd)
{
	long ret = 0;
	if ((ret = zynq_ioctl_alloc(inst, &cmd->mm))) {
		DEVERR(inst->dev_id, "could not allocate memory for bulk alloc+copyto: %ld", ret);
		return ret;
	}
	cmd->copy.dev_addr = cmd->mm.dev_addr;
	if ((ret = zynq_ioctl_copyto(inst, &cmd->copy))) {
		DEVERR(inst->dev_id, "failed to copy memory to %pad: %ld", &cmd->mm.dev_addr, ret);
		return ret;
	}
	return 0;
}

static inline
long zynq_ioctl_copyfrom_free(struct tlkm_device *inst, struct tlkm_bulk_cmd *cmd)
{
	long ret = 0;
	if ((ret = zynq_ioctl_copyfrom(inst, &cmd->copy))) {
		DEVERR(inst->dev_id, "failed to copy from 0x%08llx: %ld", (u64)cmd->mm.dev_addr, ret);
		return ret;
	}
	cmd->mm.dev_addr = cmd->copy.dev_addr;
	if ((ret = zynq_ioctl_free(inst, &cmd->mm))) {
		DEVERR(inst->dev_id, "failed to free device memory at 0x%08llx: %ld",
				(u64)cmd->mm.dev_addr, ret);
		return ret;
	}
	return 0;
}

static inline
long zynq_ioctl_read(struct tlkm_device *inst, struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_read(inst, cmd);
}

static inline
long zynq_ioctl_write(struct tlkm_device *inst, struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_write(inst, cmd);
}

long zynq_ioctl(struct tlkm_device *inst, unsigned int ioctl, unsigned long data)
{
	int ret = -ENXIO;
#define _TLKM_DEV_IOCTL(NAME, name, id, dt) \
	if (ioctl == TLKM_DEV_IOCTL_ ## NAME) { \
		dt d; \
		if (copy_from_user(&d, (void __user *)data, sizeof(dt))) { \
			DEVERR(inst->dev_id, "could not copy ioctl data from user space"); \
			return -EFAULT; \
		} \
		ret = zynq_ioctl_ ## name(inst, &d); \
		if (copy_to_user((void __user *)data, &d, sizeof(dt))) { \
			DEVERR(inst->dev_id, "could not copy ioctl data to user space"); \
			return -EFAULT; \
		} \
		return ret; \
	}
	TLKM_DEV_IOCTL_CMDS
#undef _TLKM_DEV_IOCTL
	DEVERR(inst->dev_id, "received invalid ioctl: 0x%08x", ioctl);
	return ret;
}
