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
#ifndef TLKM_STATUS_H__
#define TLKM_STATUS_H__

#include <linux/bug.h>
#include <status_core.pb.h>
#include "tlkm_types.h"
struct tlkm_device;

typedef tapasco_status_Status tlkm_status;

#define TLKM_COMPONENT_MAX 16
#define TLKM_COMPONENTS_NAME_MAX 32

typedef struct tlkm_component {
	char name[TLKM_COMPONENTS_NAME_MAX];
	dev_addr_t offset;
	u64 size;
} tlkm_component_t;

int tlkm_status_init(tlkm_status *sta, struct tlkm_device *dev,
		     void __iomem *status, size_t status_size);
void tlkm_status_exit(tlkm_status *sta, struct tlkm_device *dev);

dev_addr_t tlkm_status_get_component_base(struct tlkm_device *dev,
					  const char *c);

u64 tlkm_status_get_component_size(struct tlkm_device *dev, const char *c);

#endif /* TLKM_STATUS_H__ */
