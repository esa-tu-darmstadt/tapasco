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
#ifndef PLATFORM_ASYNC_H__
#define PLATFORM_ASYNC_H__

#include <platform_types.h>

typedef struct platform_signaling platform_signaling_t;
typedef void (*platform_signal_received_f)(size_t num,
                                           platform_slot_id_t *slots);

platform_res_t platform_signaling_init(platform_devctx_t const *pctx,
                                       platform_signaling_t **a);
void platform_signaling_deinit(platform_signaling_t *a);

platform_res_t platform_signaling_wait_for_slot(platform_signaling_t *a,
                                                platform_slot_id_t const slot);
platform_res_t platform_wait_for_slot(platform_devctx_t *ctx,
                                      platform_slot_id_t const slot);

void platform_signaling_signal_received(platform_signaling_t *s,
                                        platform_signal_received_f callback);

#endif /* PLATFORM_ASYNC_H__ */
