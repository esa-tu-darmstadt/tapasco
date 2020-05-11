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
//! @file	tapasco_device.h
//! @brief	Device context struct and helper methods.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_DEVICE_H__
#define TAPASCO_DEVICE_H__

#include <platform_types.h>
#include <tapasco_jobs.h>
#include <tapasco_local_mem.h>
#include <tapasco_pemgmt.h>
#include <tapasco_types.h>

struct tapasco_devctx {
  tapasco_dev_id_t id;
  platform_info_t info;
  tapasco_pemgmt_t *pemgmt;
  tapasco_jobs_t *jobs;
  tapasco_local_mem_t *lmem;
  platform_ctx_t *pctx;
  platform_devctx_t *pdctx;
  void *private_data;
};

tapasco_res_t tapasco_create_device(tapasco_ctx_t *ctx,
                                    tapasco_dev_id_t const dev_id,
                                    tapasco_devctx_t **pdev_ctx,
                                    tapasco_device_create_flag_t const flags);
void tapasco_destroy_device(tapasco_ctx_t *ctx, tapasco_devctx_t *dev_ctx);

static inline uint32_t
tapasco_device_func_instance_count(tapasco_devctx_t *dev_ctx,
                                   tapasco_kernel_id_t const k_id) {
  assert(dev_ctx);
  return tapasco_pemgmt_count(dev_ctx->pemgmt, k_id);
}

#endif /* TAPASCO_DEVICE_H__ */
