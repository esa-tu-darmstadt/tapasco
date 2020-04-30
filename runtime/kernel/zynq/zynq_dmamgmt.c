//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
//! @file	zynq_dmamgmt.c
//! @brief	Tapasco Platform Zynq: DMA buffer management.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.esa.tu-darmstadt.de)
//!
#include <linux/dma-mapping.h>
#include "tlkm_logging.h"
#include "zynq_dmamgmt.h"
#include "gen_fixed_size_pool.h"
#include <linux/of_device.h>

static inline void init_dma_buf_t(struct dma_buf_t *buf, fsp_idx_t const idx)
{
	buf->len = 0;
	buf->handle = 0;
	buf->dma_addr = 0;
	buf->kvirt_addr = NULL;
}

MAKE_FIXED_SIZE_POOL(dmabuf, ZYNQ_DMAMGMT_POOLSZ, struct dma_buf_t,
		     init_dma_buf_t)

static struct dmabuf_fsp_t _dmabuf;

static inline ssize_t find_dma_addr(dma_addr_t const addr)
{
	ssize_t id = 0;
	while (id < ZYNQ_DMAMGMT_POOLSZ && _dmabuf.elems[id].dma_addr != addr)
		++id;
	if (id >= ZYNQ_DMAMGMT_POOLSZ)
		WRN("dma address not found: 0x%08lx", (long unsigned)addr);
	return id < ZYNQ_DMAMGMT_POOLSZ ? id : -1;
}

int zynq_dmamgmt_init(void)
{
	dmabuf_fsp_init(&_dmabuf);
	LOG(TLKM_LF_DMAMGMT, "DMA buffer management initialized: size = %u",
	    ZYNQ_DMAMGMT_POOLSZ);
	return 0;
}

void zynq_dmamgmt_exit(struct tlkm_device *inst)
{
	int i;
	for (i = 0; i < ZYNQ_DMAMGMT_POOLSZ; ++i) {
		if (_dmabuf.elems[i].kvirt_addr) {
			WRN("buffer %d in use, releasing memory!", i);
			zynq_dmamgmt_dealloc(inst, i);
		}
	}
	LOG(TLKM_LF_DMAMGMT, "DMA buffer management exited");
}

dma_addr_t zynq_dmamgmt_alloc(struct tlkm_device *inst, size_t const len, handle_t *hid)
{
	fsp_idx_t id;
	int mask;
	id = dmabuf_fsp_get(&_dmabuf);
	LOG(TLKM_LF_DMAMGMT, "len = %zu, id = %u", len, id);
	if (id == INVALID_IDX) {
		WRN("internal pool depleted: could not allocate a buffer!");
		return 0;
	}
	of_dma_configure(inst->ctrl->miscdev.this_device, NULL, true);
	mask = dma_set_coherent_mask(inst->ctrl->miscdev.this_device, 0xFFFFFFFF);
	if(mask) {
		WRN("could not set DMA mask");
	}
	_dmabuf.elems[id].kvirt_addr =
		dma_alloc_coherent(inst->ctrl->miscdev.this_device, len, &_dmabuf.elems[id].dma_addr,
				   GFP_KERNEL | __GFP_MEMALLOC);
	if (!_dmabuf.elems[id].kvirt_addr) {
		WRN("could not allocate DMA buffer of size %zu byte!", len);
		dmabuf_fsp_put(&_dmabuf, id);
		return 0;
	}
	_dmabuf.elems[id].len = len;
	LOG(TLKM_LF_DMAMGMT,
	    "len = %zu, kvirt_addr = 0x%08lx, dma_addr = 0x%08lx", len,
	    (unsigned long)_dmabuf.elems[id].kvirt_addr,
	    (unsigned long)_dmabuf.elems[id].dma_addr);
	if (hid)
		*hid = id;
	return _dmabuf.elems[id].dma_addr;
}

int zynq_dmamgmt_dealloc(struct tlkm_device *inst, handle_t const id)
{
	if (id < ZYNQ_DMAMGMT_POOLSZ && _dmabuf.elems[id].kvirt_addr) {
		LOG(TLKM_LF_DMAMGMT,
		    "id = %llu, len = %zd, kvirt_addr = 0x%08lx, dma_addr = 0x%08lx",
		    id, _dmabuf.elems[id].len,
		    (unsigned long)_dmabuf.elems[id].kvirt_addr,
		    (unsigned long)_dmabuf.elems[id].dma_addr);
		dma_free_coherent(inst->ctrl->miscdev.this_device, _dmabuf.elems[id].len,
				  _dmabuf.elems[id].kvirt_addr,
				  _dmabuf.elems[id].dma_addr);
		init_dma_buf_t(&_dmabuf.elems[id], id);
	} else {
		WRN("illegal id %llu, no deallocation", id);
		return 1;
	}
	dmabuf_fsp_put(&_dmabuf, id);
	return 0;
}

int zynq_dmamgmt_dealloc_dma(struct tlkm_device *inst, dma_addr_t const addr)
{
	return zynq_dmamgmt_dealloc(inst, find_dma_addr(addr));
}

inline struct dma_buf_t *zynq_dmamgmt_get(handle_t const id)
{
	return (id >= ZYNQ_DMAMGMT_POOLSZ || !_dmabuf.locked[id]) ?
		       NULL :
		       &_dmabuf.elems[id];
}

inline ssize_t zynq_dmamgmt_get_id(dma_addr_t const addr)
{
	return find_dma_addr(addr);
}
