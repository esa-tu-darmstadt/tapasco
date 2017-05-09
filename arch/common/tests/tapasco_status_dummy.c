//
// Copyright (C) 2016 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_status_dummy.c
//! @brief	Dummy implementation of TPC Status Core API.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <tapasco_status.h>

static tapasco_status_t _status;

tapasco_res_t tapasco_status_init(tapasco_status_t **status) {
	if (status)
		*status = &_status;
	return status && *status ? TAPASCO_SUCCESS : TAPASCO_FAILURE;
}

void tapasco_status_deinit(tapasco_status_t *status) {}

void tapasco_status_set_id(int idx, tapasco_func_id_t id) {
	_status.id[idx] = id;
}
