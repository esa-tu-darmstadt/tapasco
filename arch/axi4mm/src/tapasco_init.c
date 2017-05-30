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
//! @file	tapasco-sim.c
//! @brief	TPC API intialization implementation for the Zynq platform.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <tapasco.h>
#include <tapasco_errors.h>
#include <tapasco_jobs.h>
#include <tapasco_functions.h>
#include <tapasco_logging.h>
#include <platform.h>
#include <platform_errors.h>

// declare logging exit for flushing
// TODO: is it possible to handle this more nicely?
extern void platform_logging_exit(void);

struct tapasco_ctx {
	int conn_sock;
};

static void _flush_logs_on_sigint(int sig) {
	LOG(LALL_INIT, "caught SIGINT, flushing logs and leaving the sinking ship");
	tapasco_logging_exit();
	platform_logging_exit();
	exit(sig);
}

static int _tapasco_install_sigint_handler() {
	struct sigaction act;
	memset(&act, '\0', sizeof(act));
	act.sa_handler = &_flush_logs_on_sigint;
	return sigaction(SIGINT, &act, NULL);
}

tapasco_res_t _tapasco_init(const char *const version, tapasco_ctx_t **pctx) {
	tapasco_logging_init();
	LOG(LALL_INIT, "version: %s, expected version: %s", tapasco_version(), version);
	if (tapasco_check_version(version) != TAPASCO_SUCCESS) {
		ERR("version mismatch: found %s, expected %s", tapasco_version(), version);
		return TAPASCO_ERR_VERSION_MISMATCH;
	}

	*pctx = (tapasco_ctx_t *)malloc(sizeof(struct tapasco_ctx));
	platform_res_t pr;
	if ((pr = platform_init()) != PLATFORM_SUCCESS) {
		ERR("Platform error: %s", platform_strerror(pr));
		return TAPASCO_ERR_PLATFORM_FAILURE;
	}

	// install signal handler
	if (_tapasco_install_sigint_handler()) {
		ERR("could not install signal handler: %s", strerror(errno));
		platform_deinit();
		free(pctx);
		return TAPASCO_FAILURE;
	}
	LOG(LALL_INIT, "tapasco initialization done");
	if (*pctx) return TAPASCO_SUCCESS;

	return TAPASCO_FAILURE;
}

void tapasco_deinit(tapasco_ctx_t *ctx) {
	LOG(LALL_INIT, "shutting down TPC");
	if (ctx) {
		platform_deinit();
		free(ctx);
	}
	LOG(LALL_INIT, "all's well that ends well, bye");
	tapasco_logging_exit();
}

