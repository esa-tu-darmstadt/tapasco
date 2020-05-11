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
#ifndef PLATFORM_CTX_H__
#define PLATFORM_CTX_H__

#include <platform.h>

platform_res_t _platform_init(const char *const version, platform_ctx_t **ctx);
void platform_deinit(platform_ctx_t *ctx);

platform_res_t platform_enum_devices(platform_ctx_t *ctx, size_t *num_devices,
                                     platform_device_info_t **devs);
platform_res_t platform_create_device(platform_ctx_t *ctx,
                                      platform_devctx_t **pdctx,
                                      platform_dev_id_t const dev_id,
                                      platform_access_t const mode);
void platform_destroy_device(platform_ctx_t *ctx, platform_devctx_t *pdctx);
void platform_destroy_device_by_id(platform_ctx_t *ctx,
                                   platform_dev_id_t const dev_id);

#endif /* PLATFORM_CTX_H__ */
