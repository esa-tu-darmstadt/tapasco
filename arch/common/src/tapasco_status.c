//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
/**
 *  @file	tapasco_status.c
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <tapasco_status.h>
#include <tapasco_errors.h>

tapasco_res_t tapasco_status_init(tapasco_status_t **status)
{
	platform_res_t res = platform_status_init(status);
	if (res != PLATFORM_SUCCESS)
		return TAPASCO_ERR_PLATFORM_FAILURE;
	return TAPASCO_SUCCESS;
}

void tapasco_status_deinit(tapasco_status_t *status)
{
	platform_status_deinit(status);
}
