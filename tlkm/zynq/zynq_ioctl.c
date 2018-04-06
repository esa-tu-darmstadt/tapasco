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
long zynq_ioctl_info(struct tlkm_device_inst *inst, struct tlkm_device_info *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline
long zynq_ioctl_alloc(struct tlkm_device_inst *inst, struct tlkm_mm_cmd *cmd)
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

	dma_addr = zynq_dmamgmt_alloc(cmd->sz, &cmd->dev_addr);
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "alloc: len = %zu, dma = 0x%08lx, id = %ld",
			cmd->sz, (unsigned long) dma_addr, (long)cmd->dev_addr);
	if (! dma_addr) {
		DEVWRN(inst->dev_id, "allocation failed");
		return -ENOMEM;
	}
	return 0;
}

static inline
long zynq_ioctl_free(struct tlkm_device_inst *inst, struct tlkm_mm_cmd *cmd)
{
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "free: len = %zu, id = %ld", cmd->sz, (long)cmd->dev_addr);
	if (cmd->dev_addr >= 0) {
		zynq_dmamgmt_dealloc(cmd->dev_addr);
		cmd->dev_addr = -1;
	}
	return 0;
}

static inline
long zynq_ioctl_copyto(struct tlkm_device_inst *inst, struct tlkm_copy_cmd *cmd)
{
	struct dma_buf_t *dmab;
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyto: len = %zu, id = %ld, p = 0x%08lx",
			cmd->length, (long)cmd->dev_addr, (unsigned long) cmd->user_addr);
	// allocate, if necessary
	if (cmd->dev_addr < 0 || ! (dmab = zynq_dmamgmt_get(cmd->dev_addr))) {
		int ret;
		struct tlkm_mm_cmd mm_cmd = { .sz = cmd->length, };
		DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "allocating %zu bytes for transfer", cmd->length);
		ret = zynq_ioctl_alloc(inst, &mm_cmd);
		cmd->dev_addr = mm_cmd.dev_addr;
		if (ret) return ret;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "cmd->dev_addr = %ld", (long)cmd->dev_addr);
	dmab = zynq_dmamgmt_get(cmd->dev_addr);
	if (! dmab || ! dmab->kvirt_addr) {
		DEVERR(inst->dev_id, "something went wrong in the allocation");
		return -ENOMEM;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "dmab->kvirt_addr = 0x%08lx, dmab->dma_addr = 0x%08lx",
			(unsigned long)dmab->kvirt_addr, (unsigned long)dmab->dma_addr);
	if (copy_from_user(dmab->kvirt_addr, (void __user *) cmd->user_addr, cmd->length)) {
		DEVWRN(inst->dev_id, "could not copy all bytes from user space");
		return -EACCES;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyto finished successfully");
	return 0;
}

static inline
long zynq_ioctl_copyfrom(struct tlkm_device_inst *inst, struct tlkm_copy_cmd *cmd)
{
	struct dma_buf_t *dmab;
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE, "copyfrom: len = %zu, id = %ld, p = 0x%08lx",
			cmd->length, (long)cmd->dev_addr, (unsigned long) cmd->user_addr);
	dmab = zynq_dmamgmt_get(cmd->dev_addr);
	if (! dmab || ! dmab->kvirt_addr) {
		DEVERR(inst->dev_id, "could not get dma buffer with id = %ld", (long)cmd->dev_addr);
			return -EINVAL;
	}
	if (copy_to_user((void __user *) cmd->user_addr, dmab->kvirt_addr, cmd->length)) {
		DEVWRN(inst->dev_id, "could not copy all bytes from user space");
		return -EACCES;
	}
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "copyfrom finished successfully");
	return 0;
}

static inline
long zynq_ioctl_alloc_copyto(struct tlkm_device_inst *inst, struct tlkm_bulk_cmd *cmd)
{
	long ret = 0;
	if ((ret = zynq_ioctl_alloc(inst, &cmd->mm))) {
		DEVERR(inst->dev_id, "could not allocate memory for bulk alloc+copyto: %ld", ret);
		return ret;
	}
	cmd->copy.dev_addr = cmd->mm.dev_addr;
	if ((ret = zynq_ioctl_copyto(inst, &cmd->copy))) {
		DEVERR(inst->dev_id, "failed to copy memory to 0x%08llx: %ld", (u64)cmd->mm.dev_addr, ret);
		return ret;
	}
	return 0;
}

static inline
long zynq_ioctl_copyfrom_free(struct tlkm_device_inst *inst, struct tlkm_bulk_cmd *cmd)
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
long zynq_ioctl_read(struct tlkm_device_inst *inst, struct tlkm_copy_cmd *cmd)
{
	long ret = -ENXIO;
	void __iomem *ptr = NULL;
	void *buf = kzalloc(cmd->length, GFP_ATOMIC);
	struct zynq_device *dev = (struct zynq_device *)inst->private_data;
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "received read of %zu bytes from 0x%08llx",
			cmd->length, cmd->dev_addr);
	if (cmd->dev_addr >= ZYNQ_PLATFORM_GP1_BASE) {
		ptr = dev->gp_map[1] + (cmd->dev_addr - ZYNQ_PLATFORM_GP1_BASE);
	} else if (cmd->dev_addr < ZYNQ_PLATFORM_GP0_HIGH) {
		ptr = dev->gp_map[0] + (cmd->dev_addr - ZYNQ_PLATFORM_GP0_BASE);
	} else if (cmd->dev_addr >= ZYNQ_PLATFORM_STATUS_BASE &&
			cmd->dev_addr < ZYNQ_PLATFORM_STATUS_HIGH) {
		ptr = dev->tapasco_status + (cmd->dev_addr - ZYNQ_PLATFORM_STATUS_BASE);
	} else {
		DEVERR(inst->dev_id, "invalid address: 0x%08llx", cmd->dev_addr);
		return -ENXIO;
	}
	memcpy_fromio(buf, ptr, cmd->length);
	if ((ret = copy_to_user((u32 __user *)cmd->user_addr, buf, cmd->length))) {
		DEVERR(inst->dev_id, "could not copy all bytes from 0x%08lx to user space 0x%08lx: %ld",
				(ulong)buf, (ulong)cmd->user_addr, ret);
		ret = -EAGAIN;
	}
	kfree(buf);
	return ret;
}

static inline
long zynq_ioctl_write(struct tlkm_device_inst *inst, struct tlkm_copy_cmd *cmd)
{
	long ret = -ENXIO;
	void __iomem *ptr = NULL;
	void *buf = kzalloc(cmd->length, GFP_ATOMIC);
	struct zynq_device *dev = (struct zynq_device *)inst->private_data;
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "received write of %zu bytes to 0x%08llx",
			cmd->length, cmd->dev_addr);
	if (cmd->dev_addr > ZYNQ_PLATFORM_GP1_BASE) {
		ptr = dev->gp_map[1] + (cmd->dev_addr - ZYNQ_PLATFORM_GP1_BASE);
	} else if (cmd->dev_addr < ZYNQ_PLATFORM_GP0_HIGH) {
		ptr = dev->gp_map[0] + (cmd->dev_addr - ZYNQ_PLATFORM_GP0_BASE);
	} else if (cmd->dev_addr >= ZYNQ_PLATFORM_STATUS_BASE &&
			cmd->dev_addr < ZYNQ_PLATFORM_STATUS_HIGH) {
		ptr = dev->tapasco_status + (cmd->dev_addr - ZYNQ_PLATFORM_STATUS_BASE);
	} else {
		DEVERR(inst->dev_id, "invalid address: 0x%08llx", cmd->dev_addr);
		return -ENXIO;
	}
	if (ptr && copy_from_user(buf, (void __user *)cmd->user_addr, cmd->length)) {
		DEVERR(inst->dev_id, "could not copy all bytes from user space");
		ret = -EAGAIN;
		goto err;
	}
	memcpy_toio(ptr, buf, cmd->length);
err:
	kfree(buf);
	return ret;
}

long zynq_ioctl(struct tlkm_device_inst *inst, unsigned int ioctl, unsigned long data)
{
	int ret = -ENXIO;
#define _TLKM_DEV_IOCTL(NAME, name, id, dt) \
	if (ioctl == TLKM_DEV_IOCTL_ ## NAME) { \
		dt d; \
		DEVLOG(inst->dev_id, TLKM_LF_IOCTL, "received ioctl: 0x%08x", ioctl); \
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
