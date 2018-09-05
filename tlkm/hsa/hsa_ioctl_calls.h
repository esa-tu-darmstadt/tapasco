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
 * @file hsa_ioctl_calls.c
 * @brief TODO
 * */

#ifndef __HSA_IOCTL_CALLS_H
#define __HSA_IOCTL_CALLS_H

/******************************************************************************/

#include <linux/ioctl.h>

/******************************************************************************/

struct hsa_ioctl_params {
	void *addr;
	int offset;
};

#define HSA_QUEUE_LENGTH 128
#define HSA_QUEUE_LENGTH_MOD2 7
#define HSA_SIGNALS 128
#define HSA_PACKAGE_BYTES 64

// 64 byte dummy package for struct size
typedef uint8_t hsa_package_t[HSA_PACKAGE_BYTES];

struct hsa_mmap_space {
	hsa_package_t queue[HSA_QUEUE_LENGTH];
	uint32_t pasids[HSA_QUEUE_LENGTH];
	uint64_t read_index;
	uint64_t signals[HSA_SIGNALS];
};

/* Magic character for unique identification */
#define HSA_ID_GROUP_BLOCKING 'h'

/******************************************************************************/
/* ids and corresponding sizes for every call */

#define HSA_ID_0    0
#define HSA_SIZE_0  uint8_t[sizeof(struct hsa_ioctl_params)] /*  */

#define HSA_ID_1    1
#define HSA_SIZE_1  uint8_t[sizeof(struct hsa_ioctl_params)] /*  */

#define HSA_ID_2    2
#define HSA_SIZE_2  uint8_t[sizeof(struct hsa_ioctl_params)] /*  */

#define HSA_ID_3    3
#define HSA_SIZE_3  uint8_t[sizeof(struct hsa_ioctl_params)] /*  */

/******************************************************************************/
/* definition of cmds with _IOWR wrapper function to get system-wide unique numbers */

#define IOCTL_CMD_HSA_SIGNAL_ALLOC _IOR(HSA_ID_GROUP_BLOCKING, HSA_ID_0, HSA_SIZE_0)
#define IOCTL_CMD_HSA_SIGNAL_DEALLOC _IOR(HSA_ID_GROUP_BLOCKING, HSA_ID_1, HSA_SIZE_1)

#define IOCTL_CMD_HSA_DOORBELL_ASSIGN _IOR(HSA_ID_GROUP_BLOCKING, HSA_ID_2, HSA_SIZE_2)
#define IOCTL_CMD_HSA_DOORBELL_UNASSIGN _IOR(HSA_ID_GROUP_BLOCKING, HSA_ID_3, HSA_SIZE_3)

/******************************************************************************/

#endif
