//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
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
//! @file	tapasco_axi4mm.c
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <tapasco.h>
#include <tapasco_context.h>
#include <tapasco_errors.h>
#include <tapasco_logging.h>

struct tapasco_ctx {
	tapasco_dev_ctx_t *dev_ctx;
};

tapasco_dev_ctx_t *tapasco_context_device(tapasco_ctx_t *ctx)
{
	return ctx->dev_ctx;
}

// declare logging exit for flushing
// TODO: is it possible to handle this more nicely?
extern void platform_logging_exit(void);

static
void _flush_logs_on_sigint(int sig)
{
	LOG(LALL_INIT, "caught SIGINT, flushing logs and leaving the sinking ship");
	tapasco_logging_exit();
	platform_logging_exit();
	exit(sig);
}

static
int _tapasco_install_sigint_handler()
{
	struct sigaction act;
	memset(&act, '\0', sizeof(act));
	act.sa_handler = &_flush_logs_on_sigint;
	return sigaction(SIGINT, &act, NULL);
}

tapasco_res_t _tapasco_init(const char *const version, tapasco_ctx_t **ctx)
{
	tapasco_logging_init();
	LOG(LALL_INIT, "version: %s, expected version: %s", tapasco_version(),
			version);
	if (tapasco_check_version(version) != TAPASCO_SUCCESS) {
		ERR("version mismatch: found %s, expected %s",
				tapasco_version(), version);
		return TAPASCO_ERR_VERSION_MISMATCH;
	}

	*ctx = (tapasco_ctx_t *)malloc(sizeof(**ctx));
	if (! *ctx) {
		ERR("could not allocate tapasco context");
		return TAPASCO_ERR_OUT_OF_MEMORY;
	}

	// install signal handler
	if (_tapasco_install_sigint_handler()) {
		ERR("could not install signal handler: %s", strerror(errno));
		free(*ctx);
		return TAPASCO_ERR_UNKNOWN_ERROR;
	}
	LOG(LALL_INIT, "tapasco initialization done");

	return TAPASCO_ERR_UNKNOWN_ERROR;
}

void tapasco_deinit(tapasco_ctx_t *ctx)
{
	LOG(LALL_INIT, "shutting down TPC");
	if (ctx) {
		free(ctx);
	}
	LOG(LALL_INIT, "all's well that ends well, bye");
	tapasco_logging_exit();
}
