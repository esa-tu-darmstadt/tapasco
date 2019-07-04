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
//! @file	tapasco_context.h
//! @brief	Global context helper methods.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_CONTEXT_H__
#define TAPASCO_CONTEXT_H__

#include <platform.h>
#include <tapasco_types.h>

struct tapasco_ctx {
  platform_ctx_t *pctx;
  size_t num_devices;
  platform_device_info_t *devinfo;
  tapasco_devctx_t *devs[PLATFORM_MAX_DEVS];
};

#endif /* TAPASCO_CONTEXT_H__ */
