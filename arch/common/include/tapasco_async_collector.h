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
//! @file	tapasco_async_collector.h
//! @brief	Manages the collector thread that gathers finished jobs.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_ASYNC_COLLECTOR_H__
#define TAPASCO_ASYNC_COLLECTOR_H__

#include <tapasco_types.h>
#include <tapasco_async.h>

tapasco_res_t tapasco_async_collector_init(tapasco_async_t *a);
void tapasco_async_collector_deinit(tapasco_async_t *a);

#endif /* TAPASCO_ASYNC_COLLECTOR_H__ */
