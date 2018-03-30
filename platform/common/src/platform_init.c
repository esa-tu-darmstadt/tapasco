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
 *  @file	platform_init.c
 *  @brief	Basic init routines for libplatform.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/

platform_res_t *_platform_init(const char *const version, platform_devctx_t **ctx)
{
	platform_logging_init();
	LOG(LPLL_INIT, "version: %s, expected version: %s", platform_version(),
			version);
	if (platform_check_version(version) != PLATFORM_SUCCESS) {
		ERR("version mismatch: found %s, expected: %s",
				platform_version(), version);
		return PERR_VERSION_MISMATCH;
	}

	platform_res_t const r = platform_context_init(ctx);
	if (r != PLATFORM_SUCCESS) {
		ERR("could not initialize platform device context: %s (%d)",
				platform_strerror(r), r);
		return r;
	}
	return PLATFORM_SUCCESS;
}

void platform_deinit(platform_context_t *ctx)
{
	platform_context_deinit(ctx);
}
