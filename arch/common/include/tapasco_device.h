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
//! @file	tapasco_device.h
//! @brief	Device context struct and helper methods.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! 
#ifndef TAPASCO_DEVICE_H__
#define TAPASCO_DEVICE_H__

#include <tapasco.h>
#include <tapasco_functions.h>

tapasco_functions_t *tapasco_device_functions(tapasco_dev_ctx_t *dev_ctx);

#endif /* TAPASCO_DEVICE_H__ */
