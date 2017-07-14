//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
 * @file dma_ioctl_calls.c
 * @brief Define all ioctl commands with corresponding structs for the dma char device
	these calls will be used by the platform_api to start a dma transfer on the pci-bus
	Two different modes can be used here: either choose mmaped memory for zero copy access
	or let the system call handle copying the data by itself
 * */

#ifndef __DMA_IOCTL_CALLS_H
#define __DMA_IOCTL_CALLS_H

/******************************************************************************/

#include <linux/ioctl.h>

/******************************************************************************/

/* Maximal size of Parameter array (type uint32_t) */
#define IOCTL_DMA_MAX_PARAM_SIZE 6

struct dma_ioctl_params {
	uint64_t host_addr;
	uint64_t fpga_addr;
	uint32_t btt;
};

/* Magic character for unique identification */
#define DMA_ID_GROUP_BLOCKING 'a'

/******************************************************************************/
/* ids and corresponding sizes for every call */

#define DMA_ID_0	0
#define DMA_SIZE_0	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* btt */

#define DMA_ID_1	1
#define DMA_SIZE_1	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* btt */

#define DMA_ID_2	2
#define DMA_SIZE_2	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* host_addr - fpga_addr - btt */

#define DMA_ID_3	3
#define DMA_SIZE_3	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* host_addr - fpga_addr - btt */

#define DMA_ID_4	4
#define DMA_SIZE_4	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* fpga_addr */

#define DMA_ID_5	5
#define DMA_SIZE_5	uint32_t[IOCTL_DMA_MAX_PARAM_SIZE] /* fpga_addr */


/******************************************************************************/
/* definition of cmds with _IOWR wrapper function to get system-wide unique numbers */

#define IOCTL_CMD_DMA_READ_MMAP _IOR(DMA_ID_GROUP_BLOCKING, DMA_ID_0, DMA_SIZE_0)
#define IOCTL_CMD_DMA_WRITE_MMAP _IOW(DMA_ID_GROUP_BLOCKING, DMA_ID_1, DMA_SIZE_1)

#define IOCTL_CMD_DMA_READ_BUF _IOWR(DMA_ID_GROUP_BLOCKING, DMA_ID_2, DMA_SIZE_2)
#define IOCTL_CMD_DMA_WRITE_BUF _IOWR(DMA_ID_GROUP_BLOCKING, DMA_ID_3, DMA_SIZE_3)

#define IOCTL_CMD_DMA_SET_MEM_H2L _IOWR(DMA_ID_GROUP_BLOCKING, DMA_ID_4, DMA_SIZE_4)
#define IOCTL_CMD_DMA_SET_MEM_L2H _IOWR(DMA_ID_GROUP_BLOCKING, DMA_ID_5, DMA_SIZE_5)

/******************************************************************************/

#endif // __DMA_IOCTL_CALLS_H
