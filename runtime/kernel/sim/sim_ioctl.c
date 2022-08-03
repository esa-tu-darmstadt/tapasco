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
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/gfp.h>

#include "tlkm_logging.h"
#include "tlkm_device.h"
#include "tlkm_device_ioctl_cmds.h"
#include "sim_device.h"

static inline long sim_ioctl_info(struct tlkm_device *inst,
				   struct tlkm_device_info *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long sim_ioctl_size(struct tlkm_device *inst,
				   struct tlkm_size_cmd *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long sim_ioctl_reg_int(struct tlkm_device *inst,
				      struct tlkm_register_interrupt *info)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

long sim_ioctl_dma_buffer_allocate(
	struct tlkm_device *inst, struct tlkm_dma_buffer_allocate __user *param)
{
	ERR("Eventfd for platform interrupts is not implemented, yet.");
	return -EFAULT;
}

long sim_ioctl_dma_buffer_free(struct tlkm_device *inst,
				struct tlkm_dma_buffer_op __user *param)
{
	ERR("Eventfd for platform interrupts is not implemented, yet.");
	return -EFAULT;
}

long sim_ioctl_dma_buffer_to_dev(struct tlkm_device *inst,
				  struct tlkm_dma_buffer_op __user *param)
{
	ERR("Eventfd for platform interrupts is not implemented, yet.");
	return -EFAULT;
}

long sim_ioctl_dma_buffer_from_dev(struct tlkm_device *inst,
				    struct tlkm_dma_buffer_op __user *param)
{
	ERR("Eventfd for platform interrupts is not implemented, yet.");
	return -EFAULT;
}

static inline long sim_ioctl_alloc(struct tlkm_device *inst,
				    struct tlkm_mm_cmd *cmd)
{
	return 0;
}

static inline long sim_ioctl_free(struct tlkm_device *inst,
				   struct tlkm_mm_cmd *cmd)
{
	return 0;
}

static inline long sim_ioctl_copyto(struct tlkm_device *inst,
				     struct tlkm_copy_cmd *cmd)
{
	return 0;
}

static inline long sim_ioctl_copyfrom(struct tlkm_device *inst,
				       struct tlkm_copy_cmd *cmd)
{
	return 0;
}

static inline long sim_ioctl_alloc_copyto(struct tlkm_device *inst,
					   struct tlkm_bulk_cmd *cmd)
{
	return 0;
}

static inline long sim_ioctl_copyfrom_free(struct tlkm_device *inst,
					    struct tlkm_bulk_cmd *cmd)
{
  return 0;
}

static inline long sim_ioctl_read(struct tlkm_device *inst,
				   struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_read(inst, cmd);
}

static inline long sim_ioctl_write(struct tlkm_device *inst,
				    struct tlkm_copy_cmd *cmd)
{
	return tlkm_platform_write(inst, cmd);
}

static inline long sim_ioctl_svm_launch(struct tlkm_device *inst,
					 struct tlkm_svm_init_cmd *cmd)
{
	ERR("SVM is not implemented on the sim platform");
	return -EFAULT;
}

static inline long
sim_ioctl_svm_migrate_to_dev(struct tlkm_device *inst,
			      struct tlkm_svm_migrate_cmd *cmd)
{
	ERR("SVM is not implemented on the sim platform");
	return -EFAULT;
}

static inline long
sim_ioctl_svm_migrate_to_ram(struct tlkm_device *inst,
			      struct tlkm_svm_migrate_cmd *cmd)
{
	ERR("SVM is not implemented on the sim platform");
	return -EFAULT;
}

long sim_ioctl(struct tlkm_device *inst, unsigned int ioctl,
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
		ret = sim_ioctl_##name(inst, &d);                             \
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
