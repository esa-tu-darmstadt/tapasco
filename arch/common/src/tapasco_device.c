//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TAPASCO).
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
//! @file	tapasco_device.c
//! @brief	Device context struct and helper methods.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! 
#include <tapasco_device.h>
#include <tapasco_logging.h>
#include <platform.h>

tapasco_res_t tapasco_device_info(tapasco_dev_ctx_t const *dev_ctx,
		platform_info_t *info)
{
	platform_ctx_t const *p = tapasco_device_platform(dev_ctx);
	platform_res_t r = platform_info(p, info);
	if (r != PLATFORM_SUCCESS) {
		ERR("failed to get device info: %s (%d)",
				platform_strerror(r), r);
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}
	return TAPASCO_SUCCESS;
}
