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
//! @file	tapasco_context.c
//! @brief	Global TaPaSCo context struct:
//!             Holds references to device contexts as well as any Architecture-
//! 		specific global data.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! 
#include <signal.h>
#include <string.h>
#include <errno.h>
#include <tapasco.h>
#include <tapasco_logging.h>
#include <tapasco_types.h>
#include <tapasco_context.h>

extern
void platform_logging_deinit(void);

static
void _flush_logs_on_sigint(int sig)
{
	LOG(LALL_INIT, "caught SIGINT, flushing logs and leaving the sinking ship");
	tapasco_logging_exit();
	platform_logging_deinit();
	exit(sig);
}

static
int _tapasco_install_sigint_handler()
{
	struct sigaction act;
	memset(&act, '\0', sizeof(act));
	act.sa_handler = &_flush_logs_on_sigint;
	return sigaction(SIGINT, &act, NULL) + sigaction(SIGABRT, &act, NULL);
}

tapasco_res_t _tapasco_init(const char *const version, tapasco_ctx_t **ctx)
{
	platform_res_t res;
	tapasco_res_t r;
	tapasco_logging_init();
	LOG(LALL_INIT, "version: %s, expected version: %s", tapasco_version(), version);
	if (tapasco_check_version(version) != TAPASCO_SUCCESS) {
		ERR("version mismatch: found %s, expected %s", tapasco_version(), version);
		return TAPASCO_ERR_VERSION_MISMATCH;
	}

	*ctx = (tapasco_ctx_t *)calloc(sizeof(**ctx), 1);
	tapasco_ctx_t *c = *ctx;
	if (! c) {
		ERR("could not allocate tapasco context");
		return TAPASCO_ERR_OUT_OF_MEMORY;
	}

	// install signal handler
	if (_tapasco_install_sigint_handler()) {
		ERR("could not install signal handler: %s", strerror(errno));
		free(*ctx);
		return TAPASCO_ERR_UNKNOWN_ERROR;
	}

	if ((res = platform_init(&c->pctx)) != PLATFORM_SUCCESS) {
		ERR("could not initialize platform: %s (%d)", platform_strerror(res), res);
		r = TAPASCO_ERR_PLATFORM_FAILURE;
		goto err_platform;
	}
	LOG(LALL_INIT, "initialized platform");

	if ((res = platform_enum_devices(c->pctx, &c->num_devices, &c->devinfo)) != PLATFORM_SUCCESS) {
		ERR("could not enumerate devices: %s (%d)", platform_strerror(res), res);
		r = TAPASCO_ERR_PLATFORM_FAILURE;
		goto err_enum_devices;
	}
	LOG(LALL_INIT, "found %zu TaPaSCo device%c", c->num_devices, c->num_devices != 1 ? 's' : ' ');

	if (c->num_devices == 0) {
		ERR("no TaPaSCo devices found, exiting");
		r = TAPASCO_ERR_DEVICE_NOT_FOUND;
		goto err_enum_devices;
	}

	LOG(LALL_INIT, "TaPaSCo initialization done");
	return TAPASCO_SUCCESS;

err_enum_devices:
	platform_deinit(c->pctx);
err_platform:
	free(*ctx);
	return r;
}

void tapasco_deinit(tapasco_ctx_t *ctx)
{
	LOG(LALL_INIT, "shutting down TaPaSCo");
	if (ctx) {
		if (ctx->pctx) {
			platform_deinit(ctx->pctx);
			ctx->pctx = NULL;
		}
		free(ctx);
	}
	LOG(LALL_INIT, "all's well that ends well, bye");
	tapasco_logging_exit();
}
