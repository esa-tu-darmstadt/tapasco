//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (PLATFORM).
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
#ifndef PLATFORM_INFO_H__
#define PLATFORM_INFO_H__

#include <stdint.h>
#include <platform_global.h>

typedef struct platform_info {
	uint32_t magic_id;
	uint32_t num_intc;
	uint32_t caps0;
	uint32_t vivado_version;
	uint32_t tapasco_version;
	uint32_t compose_ts;
	struct {
		uint32_t host;
		uint32_t design;
		uint32_t memory;
	} clock;
	uint32_t kernel_id[PLATFORM_NUM_SLOTS];
	uint32_t memory[PLATFORM_NUM_SLOTS];
} platform_info_t;

#endif /* PLATFORM_INFO_H__ */
