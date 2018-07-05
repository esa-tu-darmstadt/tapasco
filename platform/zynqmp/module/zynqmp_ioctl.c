//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
 *  @file	zynqmp_ioctl.c
 *  @brief
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <asm/uaccess.h>

#include "zynqmp_logging.h"
#include "zynqmp_ioctl.h"
#include "zynqmp_ioctl_cmds.h"
#include "zynqmp_dmamgmt.h"

static struct zynqmp_ioctl_state_t {
	dev_t			devno;
	struct miscdevice	mdev;
} zynqmp_ioctl;

/** @defgroup zynqmp_ioctl_cmds Command implementations
 *  @{ **/
static inline int zynqmp_ioctl_cmd_alloc(struct zynqmp_ioctl_cmd_t *cmd)
{
	struct dma_buf_t *dmab;
	if (cmd->length == 0 || cmd->length > (1 << 27)) {
		WRN("invalid length: %zu bytes", cmd->length);
		return -EINVAL;
	}
	if (cmd->id >= 0 && (dmab = zynqmp_dmamgmt_get(zynqmp_ioctl.mdev.this_device, cmd->id))) {
		WRN("buffer with id %ld is already allocated, aborting", cmd->id);
		return -EINVAL;
	}

	cmd->dma_addr = zynqmp_dmamgmt_alloc(zynqmp_ioctl.mdev.this_device, cmd->length, &cmd->id);
	LOG(ZYNQ_LL_IOCTL, "alloc: len = %zu, dma = 0x%08lx, id = %lu",
	    cmd->length, (unsigned long) cmd->dma_addr, cmd->id);
	if (! cmd->dma_addr) {
		WRN("allocation failed");
		return -ENOMEM;
	}
	return 0;
}

static inline int zynqmp_ioctl_cmd_free(struct zynqmp_ioctl_cmd_t *cmd)
{
	LOG(ZYNQ_LL_IOCTL, "free: len = %zu, dma = 0x%08lx, id = %lu",
	    cmd->length, (unsigned long) cmd->dma_addr, cmd->id);
	// try to find buffer by DMA address
	if (cmd->id < 0 && cmd->dma_addr)
		cmd->id = zynqmp_dmamgmt_get_id(zynqmp_ioctl.mdev.this_device, cmd->dma_addr);
	if (cmd->id >= 0) {
		zynqmp_dmamgmt_dealloc(zynqmp_ioctl.mdev.this_device, cmd->id);
		cmd->dma_addr = 0;
		cmd->id = -1;
	}
	return 0;
}

static inline int zynqmp_ioctl_cmd_copyto(struct zynqmp_ioctl_cmd_t *cmd)
{
	struct dma_buf_t *dmab;
	LOG(ZYNQ_LL_IOCTL, "copyto: len = %zu, dma = 0x%08lx, id = %lu, p = 0x%08lx",
	    cmd->length, (unsigned long) cmd->dma_addr, cmd->id,
	    (unsigned long) cmd->data);
	// try to find buffer by DMA address
	if (cmd->id < 0 && cmd->dma_addr)
		cmd->id = zynqmp_dmamgmt_get_id(zynqmp_ioctl.mdev.this_device, cmd->dma_addr);
	// allocate, if necessary
	if (cmd->id < 0 || ! (dmab = zynqmp_dmamgmt_get(zynqmp_ioctl.mdev.this_device, cmd->id))) {
		int ret;
		cmd->id = -1;
		LOG(ZYNQ_LL_IOCTL, "allocating %zu bytes for transfer", cmd->length);
		ret = zynqmp_ioctl_cmd_alloc(cmd);
		if (ret) return ret;
	}
	LOG(ZYNQ_LL_IOCTL, "cmd->id = %ld", cmd->id);
	dmab = zynqmp_dmamgmt_get(zynqmp_ioctl.mdev.this_device, cmd->id);
	if (! dmab || ! dmab->kvirt_addr) {
		ERR("something went wrong in the allocation");
		return -ENOMEM;
	}
	LOG(ZYNQ_LL_IOCTL, "dmab->kvirt_addr = 0x%08lx, dmab->dma_addr = 0x%08lx",
	    (unsigned long)dmab->kvirt_addr,
	    (unsigned long)dmab->dma_addr);
	if (copy_from_user(dmab->kvirt_addr, (void __user *) cmd->data, cmd->length)) {
		WRN("could not copy all bytes from user space");
		return -EACCES;
	}
	LOG(ZYNQ_LL_IOCTL, "copyto finished successfully");
	return 0;
}

static inline int zynqmp_ioctl_cmd_copyfrom(struct zynqmp_ioctl_cmd_t *cmd, int const free)
{
	struct dma_buf_t *dmab;
	LOG(ZYNQ_LL_DEVICE, "copyfrom: len = %zu, dma = 0x%08lx, id = %lu, p = 0x%08lx",
	    cmd->length, (unsigned long) cmd->dma_addr, cmd->id,
	    (unsigned long) cmd->data);
	// try to find buffer by DMA address
	if (cmd->id < 0 && cmd->dma_addr)
		cmd->id = zynqmp_dmamgmt_get_id(zynqmp_ioctl.mdev.this_device, cmd->dma_addr);
	dmab = zynqmp_dmamgmt_get(zynqmp_ioctl.mdev.this_device, cmd->id);
	if (! dmab || ! dmab->kvirt_addr) {
		ERR("could not get dma buffer with id = %lu", cmd->id);
		return -EINVAL;
	}
	if (copy_to_user((void __user *) cmd->data, dmab->kvirt_addr, cmd->length)) {
		WRN("could not copy all bytes from user space");
		return -EACCES;
	}
	LOG(ZYNQ_LL_IOCTL, "copyfrom finished successfully");
	if (free) return zynqmp_ioctl_cmd_free(cmd);
	return 0;
}
/** @} **/


/** @defgroup zynqmp_ioctl_fops File operations implementations
 *  @{ **/
static long zynqmp_ioctl_fops_ioctl(struct file *fp, unsigned int ioctl_num,
                                    unsigned long p)
{
	long ret = 0;
	struct zynqmp_ioctl_cmd_t cmd;

	if (_IOC_SIZE(ioctl_num) != sizeof(cmd)) {
		WRN("illegal size of ioctl command: %zu, expected %zu bytes",
		    (size_t)_IOC_SIZE(ioctl_num), sizeof(cmd));
		return -EINVAL;
	}

	if (copy_from_user(&cmd, (void __user *) p, _IOC_SIZE(ioctl_num))) {
		WRN("could not copy all bytes of user command, aborting");
		return -EACCES;
	}

	switch (ioctl_num) {
	case ZYNQ_IOCTL_COPYTO:	  ret = zynqmp_ioctl_cmd_copyto(&cmd);      break;
	case ZYNQ_IOCTL_COPYFROM: ret = zynqmp_ioctl_cmd_copyfrom(&cmd, 0); break;
	case ZYNQ_IOCTL_COPYFREE: ret = zynqmp_ioctl_cmd_copyfrom(&cmd, 1); break;
	case ZYNQ_IOCTL_ALLOC:	  ret = zynqmp_ioctl_cmd_alloc(&cmd);       break;
	case ZYNQ_IOCTL_FREE:	  ret = zynqmp_ioctl_cmd_free(&cmd);        break;
	default: 		  ERR("unknown ioctl: 0x%08x", ioctl_num);
		return -EINVAL;
	}

	if (! ret && copy_to_user((void __user *) p, &cmd, sizeof(cmd))) {
		WRN("could not copy all bytes back to user space, aborting");
		return -EACCES;
	}
	LOG(ZYNQ_LL_IOCTL, "finished ioctl successfully");
	return ret;
}

static int zynqmp_ioctl_fops_open(struct inode *inode, struct file *fp)
{
	return 0;
}

static int zynqmp_ioctl_fops_release(struct inode *inode, struct file *fp)
{
	return 0;
}
/** @} **/

struct device *zynqmp_ioctl_get_device(void) {
	return zynqmp_ioctl.mdev.this_device;
}

/** @defgroup zynqmp_ioctl_fops_struct File operations struct
 *  @{ **/
static struct file_operations zynqmp_ioctl_fops = {
	.owner		= THIS_MODULE,
	.open		= zynqmp_ioctl_fops_open,
	.release	= zynqmp_ioctl_fops_release,
	.unlocked_ioctl = zynqmp_ioctl_fops_ioctl
};
/** @} **/

/** @defgroup zynqmp_ioctl_init Initialization functions
 *  @{
 */
int zynqmp_ioctl_init(void)
{
	int retval;
	LOG(ZYNQ_LL_IOCTL, "creating ioctl device");
	zynqmp_ioctl.mdev.minor 		= MISC_DYNAMIC_MINOR;
	zynqmp_ioctl.mdev.name		= ZYNQ_IOCTL_FN;
	zynqmp_ioctl.mdev.fops		= &zynqmp_ioctl_fops;
	retval = misc_register(&zynqmp_ioctl.mdev);
	if (retval < 0) {
		ERR("could not initialize ioctl device: %d", retval);
		return retval;
	}
	LOG(ZYNQ_LL_IOCTL, "ioctl device init'ed successfully");
	return 0;
}

void zynqmp_ioctl_exit(void)
{
	LOG(ZYNQ_LL_IOCTL, "releasing ioctl device");
	misc_deregister(&zynqmp_ioctl.mdev);
	LOG(ZYNQ_LL_IOCTL, "ioctl exited successfully");
}
/** @} **/
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
