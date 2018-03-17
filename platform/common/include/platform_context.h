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
/**
 *  @file	platform_context.h
 *  @brief	Accessors for platform context elements.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef PLATFORM_CONTEXT_H__
#define PLATFORM_CONTEXT_H__

#include <platform_addr_map.h>
#include <platform_async.h>

platform_res_t platform_context_init(platform_ctx_t **ctx);
void platform_context_deinit(platform_ctx_t *ctx);

platform_addr_map_t *platform_context_addr_map(platform_ctx_t const *ctx);
platform_async_t *platform_context_async(platform_ctx_t const *ctx);

#endif /* PLATFORM_CONTEXT_H__ */
