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
#include "pcie/pcie_device.h"
#include "pcie/pcie_svm.h"
#include "pcie/pcie_ioctl.h"

long pcie_ioctl_dma_buffer_allocate(struct tlkm_device *inst, struct tlkm_dma_buffer_allocate __user *param);
long pcie_ioctl_dma_buffer_free(struct tlkm_device *inst, struct tlkm_dma_buffer_op __user *param);
long pcie_ioctl_dma_buffer_to_dev(struct tlkm_device *inst, struct tlkm_dma_buffer_op __user *param);
long pcie_ioctl_dma_buffer_from_dev(struct tlkm_device *inst, struct tlkm_dma_buffer_op __user *param);

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

static inline long pcie_ioctl_reg_int(struct tlkm_device *inst,
				      struct tlkm_register_interrupt *info)
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
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

static inline long pcie_ioctl_copyfrom(struct tlkm_device *inst,
				       struct tlkm_copy_cmd *cmd)
{
	DEVERR(inst->dev_id, "should never be called");
	return -EFAULT;
}

long pcie_ioctl_dma_buffer_allocate(
	struct tlkm_device *inst, struct tlkm_dma_buffer_allocate __user *param)
{
	int i, err;
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)inst->private_data;

	for (i = 0; i < TLKM_PCIE_NUM_DMA_BUFFERS; ++i) {
		if (pdev->dma_buffer[i].ptr == 0) {
			DEVLOG(inst->dev_id, TLKM_LF_IOCTL,
			       "Request to allocate %zu Bytes will be served in location %d.",
			       param->size, i);

			pdev->dma_buffer[i].size = param->size;
			pdev->dma_buffer[i].direction =
				param->from_device ? FROM_DEV : TO_DEV;

			if ((err = pcie_device_dma_allocate_buffer(
				     inst->dev_id, inst,
				     &pdev->dma_buffer[i].ptr,
				     &pdev->dma_buffer[i].ptr_dev,
				     pdev->dma_buffer[i].direction,
				     pdev->dma_buffer[i].size))) {
				DEVERR(inst->dev_id,
				       "Allocate of DMA buffer failed.");
				memset(&pdev->dma_buffer[i], 0,
				       sizeof(pdev->dma_buffer[0]));
				return err;
			}

			param->buffer_id = i;
			param->addr = pdev->dma_buffer[i].ptr_dev;

			return 0;
		}
	}

	DEVERR(inst->dev_id, "No free slots for DMA buffers left.");
	return -EMFILE;
}

long pcie_ioctl_dma_buffer_free(struct tlkm_device *inst,
				struct tlkm_dma_buffer_op __user *param)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)inst->private_data;

	pcie_device_dma_free_buffer(
		inst->dev_id, inst, &pdev->dma_buffer[param->buffer_id].ptr,
		&pdev->dma_buffer[param->buffer_id].ptr_dev,
		pdev->dma_buffer[param->buffer_id].direction,
		pdev->dma_buffer[param->buffer_id].size);

	memset(&pdev->dma_buffer[param->buffer_id], 0,
	       sizeof(pdev->dma_buffer[0]));

	return 0;
}

long pcie_ioctl_dma_buffer_to_dev(struct tlkm_device *inst,
				  struct tlkm_dma_buffer_op __user *param)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)inst->private_data;

	pcie_device_dma_sync_buffer_dev(
		inst->dev_id, inst, &pdev->dma_buffer[param->buffer_id].ptr,
		&pdev->dma_buffer[param->buffer_id].ptr_dev,
		pdev->dma_buffer[param->buffer_id].direction,
		pdev->dma_buffer[param->buffer_id].size);

	return 0;
}

long pcie_ioctl_dma_buffer_from_dev(struct tlkm_device *inst,
				    struct tlkm_dma_buffer_op __user *param)
{
	struct tlkm_pcie_device *pdev =
		(struct tlkm_pcie_device *)inst->private_data;

	pcie_device_dma_sync_buffer_cpu(
		inst->dev_id, inst, &pdev->dma_buffer[param->buffer_id].ptr,
		&pdev->dma_buffer[param->buffer_id].ptr_dev,
		pdev->dma_buffer[param->buffer_id].direction,
		pdev->dma_buffer[param->buffer_id].size);

	return 0;
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

static inline long pcie_ioctl_svm_launch(struct tlkm_device *inst,
					 struct tlkm_svm_init_cmd *cmd)
{
#ifdef EN_SVM
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)
	cmd->result = pcie_launch_svm(inst);
	if (cmd->result) {
		DEVERR(inst->dev_id, "failed to launch SVM");
		return -EFAULT;
	}
	DEVLOG(inst->dev_id, TLKM_LF_SVM, "successfully launched SVM");
	return 0;
#else
	DEVERR(inst->dev_id, "SVM not supported on this kernel version");
	return -EFAULT;
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */
#else
	DEVERR(inst->dev_id,
	       "SVM not enabeld, use '--enable_svm' flag during runtime compilation");
	return -EFAULT;
#endif /* EN_SVM */
}

static inline long
pcie_ioctl_svm_migrate_to_dev(struct tlkm_device *inst,
			      struct tlkm_svm_migrate_cmd *cmd)
{
#ifdef EN_SVM
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)
	return pcie_svm_user_managed_migration_to_device(inst, cmd->vaddr,
							 cmd->size);
#else
	DEVERR(inst->dev_id, "SVM not supported on this kernel version");
	return -EFAULT;
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */
#else
	DEVERR(inst->dev_id,
	       "SVM not enabeld, use '--enable_svm' flag during runtime compilation");
	return -EFAULT;
#endif /* EN_SVM */
}

static inline long
pcie_ioctl_svm_migrate_to_ram(struct tlkm_device *inst,
			      struct tlkm_svm_migrate_cmd *cmd)
{
#ifdef EN_SVM
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 10, 0)
	return pcie_svm_user_managed_migration_to_ram(inst, cmd->vaddr,
						      cmd->size);
#else
	DEVERR(inst->dev_id, "SVM not supported on this kernel version");
	return -EFAULT;
#endif /* LINUX_VERSION_CODE >= KERNEL_VERSION(5,10,0) */
#else
	DEVERR(inst->dev_id,
	       "SVM not enabeld, use '--enable_svm' flag during runtime compilation");
	return -EFAULT;
#endif /* EN_SVM */
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
