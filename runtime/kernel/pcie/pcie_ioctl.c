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
#include <linux/uaccess.h>
#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "dma/tlkm_dma.h"
#include "user/tlkm_device_ioctl_cmds.h"

static inline long pcie_ioctl_info(struct tlkm_device *inst,
				   struct tlkm_device_info *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_size(struct tlkm_device *inst,
				   struct tlkm_size_cmd *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_alloc(struct tlkm_device *inst,
				    struct tlkm_mm_cmd *cmd)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_free(struct tlkm_device *inst,
				   struct tlkm_mm_cmd *cmd)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_alloc_copyto(struct tlkm_device *inst,
					   struct tlkm_bulk_cmd *cmd)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_copyfrom_free(struct tlkm_device *inst,
					    struct tlkm_bulk_cmd *cmd)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_copyto(struct tlkm_device *inst,
				     struct tlkm_copy_cmd *cmd)
{
	ssize_t r;
	DEVLOG(inst->dev_id, TLKM_LF_IOCTL,
	       "copyto: len = %zu, dma = %pad, p = 0x%px", cmd->length,
	       &cmd->dev_addr, cmd->user_addr);
	r = tlkm_dma_copy_to(&inst->dma[0], cmd->dev_addr, cmd->user_addr,
			     cmd->length);
	if (!r) {
		tlkm_perfc_total_usr2dev_transfers_add(inst->dev_id, r);
	} else {
		DEVERR(inst->dev_id,
		       "could not copy %zu bytes 0x%px -> 0x%px: %zd",
		       cmd->length, (void *)cmd->user_addr,
		       (void *)cmd->dev_addr, r);
	}
	return r;
}

static inline long pcie_ioctl_copyfrom(struct tlkm_device *inst,
				       struct tlkm_copy_cmd *cmd)
{
	ssize_t r;
	DEVLOG(inst->dev_id, TLKM_LF_DEVICE,
	       "copyfrom: len = %zu, dma = %pad, p = 0x%px", cmd->length,
	       &cmd->dev_addr, cmd->user_addr);
	r = tlkm_dma_copy_from(&inst->dma[0], cmd->user_addr, cmd->dev_addr,
			       cmd->length);
	if (!r) {
		tlkm_perfc_total_dev2usr_transfers_add(inst->dev_id, r);
	} else {
		DEVERR(inst->dev_id,
		       "could not copy %zu bytes 0x%px -> 0x%px: %zd",
		       cmd->length, (void *)cmd->user_addr,
		       (void *)cmd->dev_addr, r);
	}
	return r;
}

static inline long pcie_ioctl_read(struct tlkm_device *inst,
				   struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_read(inst, cmd);
}

static inline long pcie_ioctl_write(struct tlkm_device *inst,
				    struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_write(inst, cmd);
}

long pcie_ioctl(struct tlkm_device *inst, unsigned int ioctl,
		unsigned long data)
{
	int ret = -ENXIO;
#define _TLKM_DEV_IOCTL(NAME, name, id, dt)                                    \
	if (ioctl == TLKM_DEV_IOCTL_##NAME) {                                  \
		dt d;                                                          \
		if (copy_from_user(&d, (void __user *)data, sizeof(dt))) {     \
			DEVERR(inst->dev_id,                                   \
			       "could not copy ioctl data from user space");   \
			return -EFAULT;                                        \
		}                                                              \
		ret = pcie_ioctl_##name(inst, &d);                             \
		if (copy_to_user((void __user *)data, &d, sizeof(dt))) {       \
			DEVERR(inst->dev_id,                                   \
			       "could not copy ioctl data to user space");     \
			return -EFAULT;                                        \
		}                                                              \
		return ret;                                                    \
	}
	TLKM_DEV_IOCTL_CMDS
#undef _TLKM_DEV_IOCTL
	DEVERR(inst->dev_id, "received invalid ioctl: 0x%08x", ioctl);
	return ret;
}
