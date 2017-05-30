//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
//! @file	common.h
//! @brief	Common helper functions for Platform API tests.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __COMMON_H__
#define __COMMON_H__

#include <stdio.h>
#include <stdlib.h>
#include <platform_errors.h>
#include <platform.h>

static inline int check(platform_res_t res)
{
	if (res != PLATFORM_SUCCESS) {
		fprintf(stderr, "platform-error: %s\n", platform_strerror(res));
		return 0;
	}
	return 1;
}

static inline int clock_period(void)
{
	return getenv("TAPASCO_FREQ") ? (1000 / strtoul(getenv("TAPASCO_FREQ"), NULL, 0)) : 4;
}

#endif /* __COMMON_H__ */
