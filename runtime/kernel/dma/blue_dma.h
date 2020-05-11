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

#ifndef BLUE_DMA_H__
#define BLUE_DMA_H__

#include <linux/interrupt.h>
#include "tlkm_dma.h"
#include "tlkm_types.h"

int blue_dma_init(struct dma_engine *dma);
irqreturn_t blue_dma_intr_handler_read(int irq, void *dev_id);
irqreturn_t blue_dma_intr_handler_write(int irq, void *dev_id);
ssize_t blue_dma_copy_from(struct dma_engine *dma, dma_addr_t krn_addr,
			   dev_addr_t dev_addr, size_t len);
ssize_t blue_dma_copy_to(struct dma_engine *dma, dev_addr_t dev_addr,
			 dma_addr_t krn_addr, size_t len);

#endif /* BLUE_DMA_H__ */
