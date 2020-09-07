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
//! @file	zynq_dmamgmt.h
//! @brief	Tapasco Platform Zynq: DMA buffer management.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.esa.tu-darmstadt.de)
//!
#ifndef ZYNQ_DMAMGMT_H__
#define ZYNQ_DMAMGMT_H__

#include "tlkm_types.h"
#include "tlkm_device.h"
#include "tlkm_control.h"

#define ZYNQ_DMAMGMT_POOLSZ 1024U

typedef u64 handle_t;

struct dma_buf_t {
	size_t len;
	unsigned long handle;
	dma_addr_t dma_addr;
	void *kvirt_addr;
};

int zynq_dmamgmt_init(void);
void zynq_dmamgmt_exit(struct tlkm_device *inst);
dma_addr_t zynq_dmamgmt_alloc(struct tlkm_device *inst, size_t const len,
			      handle_t *hid);
int zynq_dmamgmt_dealloc(struct tlkm_device *inst, handle_t const id);
int zynq_dmamgmt_dealloc_dma(struct tlkm_device *inst, dma_addr_t const addr);
struct dma_buf_t *zynq_dmamgmt_get(handle_t const id);
ssize_t zynq_dmamgmt_get_id(dma_addr_t const addr);

#endif /* ZYNQ_DMAMGMT_H__ */
