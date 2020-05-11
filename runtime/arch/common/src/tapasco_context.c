/*
 * Copyright (c) 2014-2020 Embedded Systems and Applications, TU Darmstadt.
 *
 * This file is part of TaPaSCo
 * (see https://github.com/esa-tu-darmstadt/tapasco).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
//! @file	tapasco_context.c
//! @brief	Global TaPaSCo context struct:
//!             Holds references to device contexts as well as any Architecture-
//! 		specific global data.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <errno.h>
#include <signal.h>
#include <string.h>
#include <tapasco.h>
#include <tapasco_context.h>
#include <tapasco_logging.h>
#include <tapasco_types.h>

static tapasco_ctx_t *_emergency_ctx = NULL;

tapasco_res_t _tapasco_init(const char *const version, tapasco_ctx_t **ctx) {
  platform_res_t res;
  tapasco_res_t r;
  tapasco_logging_init();
  LOG(LALL_INIT, "version: %s, expected version: %s", tapasco_version(),
      version);
  if (tapasco_check_version(version) != TAPASCO_SUCCESS) {
    ERR("version mismatch: found %s, expected %s", tapasco_version(), version);
    return TAPASCO_ERR_VERSION_MISMATCH;
  }

  _emergency_ctx = *ctx = (tapasco_ctx_t *)calloc(sizeof(**ctx), 1);
  tapasco_ctx_t *c = *ctx;
  if (!c) {
    ERR("could not allocate tapasco context");
    return TAPASCO_ERR_OUT_OF_MEMORY;
  }

  if ((res = platform_init(&c->pctx)) != PLATFORM_SUCCESS) {
    ERR("could not initialize platform: %s (" PRIres ")",
        platform_strerror(res), res);
    r = TAPASCO_ERR_PLATFORM_FAILURE;
    goto err_platform;
  }
  LOG(LALL_INIT, "initialized platform");

  if ((res = platform_enum_devices(c->pctx, &c->num_devices, &c->devinfo)) !=
      PLATFORM_SUCCESS) {
    ERR("could not enumerate devices: %s (" PRIres ")", platform_strerror(res),
        res);
    r = TAPASCO_ERR_PLATFORM_FAILURE;
    goto err_enum_devices;
  }
  LOG(LALL_INIT, "found %zu TaPaSCo device%c", c->num_devices,
      c->num_devices != 1 ? 's' : ' ');

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

void tapasco_deinit(tapasco_ctx_t *ctx) {
  LOG(LALL_INIT, "shutting down TaPaSCo");
  if (ctx) {
    for (size_t d = 0; d < PLATFORM_MAX_DEVS; ++d) {
      if (ctx->devs[d]) {
        tapasco_destroy_device(ctx, ctx->devs[d]);
        ctx->devs[d] = NULL;
      }
    }
    if (ctx->pctx) {
      platform_deinit(ctx->pctx);
      ctx->pctx = NULL;
    }
    free(ctx);
  }
  LOG(LALL_INIT, "all's well that ends well, bye");
  tapasco_logging_deinit();
}
