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
//! @file	dma-mgmt.h
//! @brief	Tapasco Platform Zynq: DMA buffer management.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.esa.tu-darmstadt.de)
//!
#ifndef ___ZYNQ_DMAMGMT_H__
#define ___ZYNQ_DMAMGMT_H__

#include <linux/device.h>
#include "zynq_platform.h"

#define ZYNQ_DMAMGMT_POOLSZ		 ZYNQ_PLATFORM_MAXMEMHANDLES

struct dma_buf_t {
	size_t len;
	u32 handle;
	dma_addr_t dma_addr;
	void * kvirt_addr;
};

int zynq_dmamgmt_init(void);
void zynq_dmamgmt_exit(void);
dma_addr_t zynq_dmamgmt_alloc(struct device *dev, size_t const len,
		unsigned long *hid);
int zynq_dmamgmt_dealloc(struct device *dev, u32 const id);
int zynq_dmamgmt_dealloc_dma(struct device *dev, dma_addr_t const id);
struct dma_buf_t *zynq_dmamgmt_get(struct device *dev, u32 const id);
ssize_t zynq_dmamgmt_get_id(struct device *dev, dma_addr_t const addr);

#endif /* ___ZYNQ_DMAMGMT_H__ */
