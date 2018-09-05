//
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
/**
 * @file hsa_dma_ioctl_calls.c
 * @brief TODO
 * */

#ifndef __HSA_DMA_IOCTL_CALLS_H
#define __HSA_DMA_IOCTL_CALLS_H

/******************************************************************************/

#include <linux/ioctl.h>

/******************************************************************************/

struct hsa_dma_ioctl_params {
	uint64_t data;
};

/* Magic character for unique identification */
#define HSA_DMA_ID_GROUP_BLOCKING 'd'

/******************************************************************************/
/* ids and corresponding sizes for every call */

#define HSA_DMA_ID_0    0
#define HSA_DMA_SIZE_0  uint8_t[sizeof(struct hsa_dma_ioctl_params)] /*  */

#define HSA_DMA_ID_1    1
#define HSA_DMA_SIZE_1  uint8_t[sizeof(struct hsa_dma_ioctl_params)] /*  */


/******************************************************************************/
/* definition of cmds with _IOWR wrapper function to get system-wide unique numbers */

#define IOCTL_CMD_HSA_DMA_ADDR _IOR(HSA_DMA_ID_GROUP_BLOCKING, HSA_DMA_ID_0, HSA_DMA_SIZE_0)
#define IOCTL_CMD_HSA_DMA_SIZE _IOR(HSA_DMA_ID_GROUP_BLOCKING, HSA_DMA_ID_1, HSA_DMA_SIZE_0)

/******************************************************************************/

#endif
