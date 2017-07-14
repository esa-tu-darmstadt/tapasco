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
//! @file tapasco_errors.c
//! @brief Implementation of error-related messages.
//! @authors J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include "tapasco_errors.h"

#ifdef _X
	#undef _X
#endif

#define _X(constant, code, msg) msg,
static const char *const _err_msg[] = {
	"success",
	TAPASCO_ERRORS
};
#undef _X

const char *const tapasco_strerror(tapasco_res_t const res)
{
	static unsigned long const _l = (unsigned long)-TAPASCO_ERR_SENTINEL;
	unsigned long const i = (unsigned long) -res;
	return _err_msg[i < _l ? i : 0];
}
