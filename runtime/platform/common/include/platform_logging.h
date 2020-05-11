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
//! @file	platform_logging.h
//! @brief	libplatform logging functions.
//!		Internal logging functions to produce debug output; levels are
//!		bitfield that can be turned on/off individually, with the
//!		exception of all-zeroes (critical error) and 1 (warning), which
//!		are always activated.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef PLATFORM_LOGGING_H__
#define PLATFORM_LOGGING_H__

#include <log.h>
#include <platform_types.h>

#define LIBPLATFORM_LOGLEVELS                                                  \
  _LPLL(TLKM, (1 << 1))                                                        \
  _LPLL(DEVICE, (1 << 2))                                                      \
  _LPLL(INIT, (1 << 3))                                                        \
  _LPLL(MM, (1 << 4))                                                          \
  _LPLL(MEM, (1 << 5))                                                         \
  _LPLL(CTL, (1 << 6))                                                         \
  _LPLL(IRQ, (1 << 7))                                                         \
  _LPLL(DMA, (1 << 8))                                                         \
  _LPLL(STATUS, (1 << 9))                                                      \
  _LPLL(ADDR, (1 << 10))                                                       \
  _LPLL(ASYNC, (1 << 11))

typedef enum {
#define _LPLL(name, level) LPLL_##name = level,
  LIBPLATFORM_LOGLEVELS
#undef _LPLL
} platform_ll_t;

int platform_logging_init(void);
void platform_logging_deinit(void);

#define DEV_PREFIX "device #" PRIdev

#ifdef NDEBUG
#include <stdio.h>

#define LOG(l, msg, ...)                                                       \
  {}
#define DEVLOG(dev_id, l, msg, ...)                                            \
  {}

#define ERR(msg, ...)                                                          \
  fprintf(stderr, "[%s]: " msg "\n", __func__, ##__VA_ARGS__)
#define WRN(msg, ...)                                                          \
  fprintf(stderr, "[%s]: " msg "\n", __func__, ##__VA_ARGS__)

#define DEVERR(dev_id, msg, ...)                                               \
  fprintf(stderr, DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__,             \
          ##__VA_ARGS__)
#define DEVWRN(dev_id, l, msg, ...)                                            \
  fprintf(stderr, DEV_PREFIX " [%s]: " msg "\n", dev_id, __func__,             \
          ##__VA_ARGS__)
#else /* !NDEBUG */
#define LOG(l, msg, ...) log_info("[%s]: " msg, __func__, ##__VA_ARGS__)

#define DEVLOG(dev_id, l, msg, ...)                                            \
  log_info(DEV_PREFIX " [%s]: " msg, dev_id, __func__, ##__VA_ARGS__)

#define ERR(msg, ...) log_error("[%s]: " msg, __func__, ##__VA_ARGS__)
#define WRN(msg, ...) log_warn("[%s]: " msg, __func__, ##__VA_ARGS__)

#define DEVERR(dev_id, msg, ...)                                               \
  log_error(DEV_PREFIX " [%s]: " msg, dev_id, __func__, ##__VA_ARGS__)
#define DEVWRN(dev_id, msg, ...)                                               \
  log_warn(DEV_PREFIX " [%s]: " msg, dev_id, __func__, ##__VA_ARGS__)
#endif

#endif /* PLATFORM_LOGGING_H__ */
