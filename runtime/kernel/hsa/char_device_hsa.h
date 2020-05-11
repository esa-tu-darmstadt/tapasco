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

#ifndef __CHAR_DEVICE_HSA_H
#define __CHAR_DEVICE_HSA_H

/******************************************************************************/
/* Include section */
#include <linux/cdev.h>

#include "hsa_ioctl_calls.h"

/******************************************************************************/

#define HSA_UPDATE_RATE 30000

#define HSA_MEMORY_BASE_ADDR 0x0001000000000000

#define HSA_ARBITER_BASE_ADDR 0x0000
#define HSA_ARBITER_SIZE 0x1000

#define HSA_ARBITER_REGISTER_HOST_ADDR 0
#define HSA_ARBITER_REGISTER_READ_INDEX_ADDR (8 / 8)
#define HSA_ARBITER_REGISTER_FPGA_ADDR (16 / 8)
#define HSA_ARBITER_REGISTER_QUEUE_SIZE (40 / 8)
#define HSA_ARBITER_REGISTER_UPDATE_RATE (48 / 8)
#define HSA_ARBITER_REGISTER_PASID_ADDR (64 / 8)
#define HSA_ARBITER_REGISTER_WRITE_INDEX_ADDR (72 / 8)

#define HSA_ARBITER_REGISTER_ID (24 / 8)
#define HSA_ARBITER_ID 0xE5A0024

#define HSA_SIGNAL_BASE_ADDR 0x1000
#define HSA_SIGNAL_SIZE 0x1000

#define HSA_SIGNAL_ACK 0
#define HSA_SIGNAL_ADDR (0x80 / 8)
#define HSA_SIGNAL_REGISTER_ID (24 / 8)
#define HSA_SIGNAL_ID 0xE5A0025

#define TLKM_HSA_NAME "HSA_AQL_QUEUE"

#define HSA_DUMMY_DMA_BUFFER_SIZE 4 * 1024 * 1024

/******************************************************************************/

/* struct array to hold data over multiple fops-calls */
struct priv_data_struct {
	struct hsa_mmap_space *kvirt_shared_mem;

	dma_addr_t dma_shared_mem;

	uint8_t signal_allocated[HSA_SIGNALS];

	struct tlkm_device *dev;

	uint64_t *signal_base;
	uint64_t *arbiter_base;

	atomic64_t device_opened;
	struct mutex ioctl_mutex;

	struct cdev cdev;
	struct class *dev_class;

	void *dummy_kvirt;
	dma_addr_t dummy_dma;
	size_t dummy_mem_size;
};

int char_hsa_register(struct tlkm_device *tlkm_dev);
void char_hsa_unregister(void);

/******************************************************************************/

#endif
