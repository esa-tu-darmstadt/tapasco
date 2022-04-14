/*
 * Copyright (c) 2014-2021 Embedded Systems and Applications, TU Darmstadt.
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

#ifndef QDMA_H__
#define QDMA_H__

#include <linux/interrupt.h>
#include "pcie/pcie_device.h"

#define QDMA_IRQ_VEC_C2H	0
#define QDMA_IRQ_VEC_H2C	1

int pcie_is_qdma_in_use(struct tlkm_device *dev);
int pcie_qdma_init(struct tlkm_pcie_device *pdev);
int pcie_qdma_exit(struct tlkm_pcie_device *pdev);
irqreturn_t qdma_intr_handler_read(int irq, void *dev_id);
irqreturn_t qdma_intr_handler_write(int irq, void *dev_id);

#endif /* QDMA_H__ */
