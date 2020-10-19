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
//! @file	tlkm_platform.h
//! @brief	Global configuration parameters for TLKM devices.
//! authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TLKM_PLATFORM_H__
#define TLKM_PLATFORM_H__

#include <tlkm_types.h>

#define IS_BETWEEN(a, l, h) (((a) >= (l) && (a) < (h)))

#ifndef __KERNEL__
#include <stdint.h>
#define __iomem
#endif

struct platform_regspace {
	uintptr_t base;
	uintptr_t high;
	size_t size;
};

#define INIT_REGSPACE(BASE, SIZE)                                              \
	{                                                                      \
		.base = (BASE), .size = (SIZE), .high = ((BASE) + (SIZE)-1),   \
	}

struct platform {
	struct platform_regspace status;
};

#define INIT_PLATFORM(status_base, status_size)                                \
	{                                                                      \
		.status = INIT_REGSPACE((status_base), (status_size)),         \
	}

#ifdef __KERNEL__
struct platform_mmap {
	void __iomem *status;
	void __iomem *arch;
	void __iomem *plat;
};

struct tlkm_device;
struct tlkm_copy_cmd;

int tlkm_platform_status_init(struct tlkm_device *dev,
			      struct platform_mmap *mmap);
void tlkm_platform_status_exit(struct tlkm_device *dev,
			       struct platform_mmap *mmap);
int tlkm_platform_mmap_init(struct tlkm_device *dev,
			    struct platform_mmap *mmap);
void tlkm_platform_mmap_exit(struct tlkm_device *dev,
			     struct platform_mmap *mmap);

long tlkm_platform_read(struct tlkm_device *dev, struct tlkm_copy_cmd *cmd);
long tlkm_platform_write(struct tlkm_device *dev, struct tlkm_copy_cmd *cmd);

void *addr2map_off(struct tlkm_device *dev, dev_addr_t const addr);
void __iomem *addr2map(struct tlkm_device *dev, dev_addr_t const addr);

#endif /* __KERNEL__ */

#endif /* TLKM_PLATFORM_H__ */
