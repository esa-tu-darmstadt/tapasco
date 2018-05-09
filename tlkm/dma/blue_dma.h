//
// Copyright (C) 2017 Jaco A. Hofmann, TU Darmstadt
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
#ifndef BLUE_DMA_H__
#define BLUE_DMA_H__

#include <linux/interrupt.h>
#include "tlkm_dma.h"
#include "tlkm_types.h"

#define BLUE_DMA_ID				 0xE5A0023
irqreturn_t blue_dma_intr_handler_read(int irq, void * dev_id);
irqreturn_t blue_dma_intr_handler_write(int irq, void * dev_id);
ssize_t blue_dma_copy_from(struct dma_engine *dma, void *krn_addr, dev_addr_t dev_addr, size_t len);
ssize_t blue_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr, const void *krn_addr, size_t len);

#endif /* BLUE_DMA_H__ */
