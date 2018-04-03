//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
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
/**
 *  @file	platform_devctx.h
 *  @brief	Device context management.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef PLATFORM_DEVCTX_H__
#define PLATFORM_DEVCTX_H__

#include <assert.h>
#include <platform_types.h>
#include <platform_device_operations.h>

typedef struct platform_addr_map platform_addr_map_t;
typedef struct platform_signaling platform_signaling_t;

struct platform_devctx {
	platform_dev_id_t			dev_id;
	int					fd_ctrl;
	platform_access_t			mode;
	platform_device_info_t			dev_info;
	platform_info_t 			info;
	platform_addr_map_t 			*addrmap;
	platform_signaling_t 			*signaling;
	platform_device_operations_t		dops;
	void					*private_data;
};

platform_res_t platform_devctx_init(platform_ctx_t *ctx,
		platform_dev_id_t const dev_id,
		platform_access_t const mode,
		platform_devctx_t **pdctx);
void platform_devctx_deinit(platform_devctx_t *devctx);

#endif /* PLATFORM_DEVCTX_H__ */
