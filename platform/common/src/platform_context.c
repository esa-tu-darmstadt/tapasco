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
 *  @file	platform_context.c
 *  @brief	Definition of a generic platform context with local mem support.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
 #include <platform_context.h>
 #include <platform.h>
 #include <platform_addr_map.h>
 #include <platform_logging.h>

struct platform_ctx {
	platform_addr_map_t *addrmap;
};

platform_addr_map_t *platform_context_addr_map(platform_ctx_t const *ctx)
{
	return ctx->addrmap;
}

platform_res_t platform_context_init(platform_ctx_t **ctx)
{
	*ctx = (platform_ctx_t *)malloc(sizeof(**ctx));
	if (! *ctx) {
		ERR("could not allocate platform context");
		return PERR_OUT_OF_MEMORY;
	}

	platform_res_t r = platform_addr_map_init(*ctx, &(*ctx)->addrmap);
	if (r != PLATFORM_SUCCESS) {
		ERR("could not initialize platform address map: %s (%d)",
				platform_strerror(r), r);
		return r;
	}
	LOG(LPLL_INIT, "initialized platform address map");
	LOG(LPLL_INIT, "platform context initialization finished");
	return PLATFORM_SUCCESS;
}

void platform_context_deinit(platform_ctx_t *ctx)
{
	if (ctx) {
		LOG(LPLL_INIT, "destroying platform address map ...");
		platform_addr_map_deinit(ctx, ctx->addrmap);
		LOG(LPLL_INIT, "platform context destroyed, have a nice 'un");
	}
}
