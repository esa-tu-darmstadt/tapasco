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

#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_device_ioctl_cmds.h"
#include "zynq_dmamgmt.h"

static inline
long zynq_ioctl_info(struct tlkm_device_inst *inst, struct tlkm_device_info *info)
{
	ERR("should never be called");
	return -EFAULT;
}

static inline
long zynq_ioctl_alloc(struct tlkm_device_inst *inst, struct tlkm_mm_cmd *cmd)
{
	struct dma_buf_t *dmab;
	dma_addr_t dma_addr;
	if (cmd->sz == 0 || cmd->sz > (1 << 27)) {
		WRN("invalid length: %zu bytes", cmd->sz);
		return -EINVAL;
	}
	if (cmd->dev_addr >= 0 && (dmab = zynq_dmamgmt_get(cmd->dev_addr))) {
		WRN("buffer with id %ld is already allocated, aborting", (long)cmd->dev_addr);
		return -EINVAL;
	}

	dma_addr = zynq_dmamgmt_alloc(cmd->sz, &cmd->dev_addr);
	LOG(TLKM_LF_IOCTL, "alloc: len = %zu, dma = 0x%08lx, id = %ld",
			cmd->sz, (unsigned long) dma_addr, (long)cmd->dev_addr);
	if (! dma_addr) {
		WRN("allocation failed");
		return -ENOMEM;
	}
	return 0;
}

static inline
long zynq_ioctl_free(struct tlkm_device_inst *inst, struct tlkm_mm_cmd *cmd)
{
	LOG(TLKM_LF_IOCTL, "free: len = %zu, id = %ld", cmd->sz, (long)cmd->dev_addr);
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
	LOG(TLKM_LF_IOCTL, "copyto: len = %zu, id = %ld, p = 0x%08lx",
			cmd->length, (long)cmd->dev_addr, (unsigned long) cmd->user_addr);
	// allocate, if necessary
	if (cmd->dev_addr < 0 || ! (dmab = zynq_dmamgmt_get(cmd->dev_addr))) {
		int ret;
		struct tlkm_mm_cmd mm_cmd = { .sz = cmd->length, };
		LOG(TLKM_LF_IOCTL, "allocating %zu bytes for transfer", cmd->length);
		ret = zynq_ioctl_alloc(inst, &mm_cmd);
		cmd->dev_addr = mm_cmd.dev_addr;
		if (ret) return ret;
	}
	LOG(TLKM_LF_IOCTL, "cmd->dev_addr = %ld", (long)cmd->dev_addr);
	dmab = zynq_dmamgmt_get(cmd->dev_addr);
	if (! dmab || ! dmab->kvirt_addr) {
		ERR("something went wrong in the allocation");
		return -ENOMEM;
	}
	LOG(TLKM_LF_IOCTL, "dmab->kvirt_addr = 0x%08lx, dmab->dma_addr = 0x%08lx",
			(unsigned long)dmab->kvirt_addr, (unsigned long)dmab->dma_addr);
	if (copy_from_user(dmab->kvirt_addr, (void __user *) cmd->user_addr, cmd->length)) {
		WRN("could not copy all bytes from user space");
		return -EACCES;
	}
	LOG(TLKM_LF_IOCTL, "copyto finished successfully");
	return 0;
}

static inline
long zynq_ioctl_copyfrom(struct tlkm_device_inst *inst, struct tlkm_copy_cmd *cmd)
{
	struct dma_buf_t *dmab;
	LOG(TLKM_LF_DEVICE, "copyfrom: len = %zu, id = %ld, p = 0x%08lx",
			cmd->length, (long)cmd->dev_addr, (unsigned long) cmd->user_addr);
	dmab = zynq_dmamgmt_get(cmd->dev_addr);
	if (! dmab || ! dmab->kvirt_addr) {
		ERR("could not get dma buffer with id = %ld", (long)cmd->dev_addr);
			return -EINVAL;
	}
	if (copy_to_user((void __user *) cmd->user_addr, dmab->kvirt_addr, cmd->length)) {
		WRN("could not copy all bytes from user space");
		return -EACCES;
	}
	LOG(TLKM_LF_IOCTL, "copyfrom finished successfully");
	return 0;
}

long zynq_ioctl(struct tlkm_device_inst *inst, unsigned int ioctl, unsigned long data)
{
	int ret = -ENXIO;
	LOG(TLKM_LF_IOCTL, "received ioctl: 0x%08x", ioctl);
#define _TLKM_DEV_IOCTL(NAME, name, id, dt) \
	if (ioctl == TLKM_DEV_IOCTL_ ## NAME) { \
		dt d; \
		if (copy_from_user(&d, (void __user *)data, sizeof(dt))) { \
			ERR("could not copy ioctl data from user space"); \
			return -EAGAIN; \
		} \
		ret = zynq_ioctl_ ## name(inst, &d); \
		if (copy_to_user((void __user *)data, &d, sizeof(dt))) { \
			ERR("could not copy ioctl data to user space"); \
			return -EAGAIN; \
		} \
		return ret; \
	}
	TLKM_DEV_IOCTL_CMDS
#undef _TLKM_DEV_IOCTL
	ERR("received invalid ioctl: 0x%08x", ioctl);
	return ret;
}
