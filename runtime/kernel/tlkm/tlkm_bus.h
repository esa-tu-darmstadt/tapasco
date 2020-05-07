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
#ifndef TLKM_BUS_H__
#define TLKM_BUS_H__

#include "tlkm_device.h"

struct tlkm_bus;
struct tlkm_class;

int tlkm_bus_init(void);
void tlkm_bus_exit(void);

struct tlkm_device *tlkm_bus_new_device(struct tlkm_class *cls, int vendor_id,
					int product_id, void *data);
void tlkm_bus_delete_device(struct tlkm_device *dev);

void tlkm_bus_enumerate(void);

size_t tlkm_bus_num_devices(void);
struct tlkm_device *tlkm_bus_get_device(size_t idx);

#endif /* TLKM_BUS_H__ */
