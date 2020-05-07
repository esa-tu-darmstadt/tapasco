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
//! @file	tapasco_perfc.h
//! @brief	Performance counters interface for libtapasco.
//!             Defines interface to diverse performance counters for the
//!             unified TaPaSCo application library.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef TAPASCO_PERFC_H__
#define TAPASCO_PERFC_H__

#include "tapasco_types.h"

#ifdef _PC
#undef _PC
#endif

#define TAPASCO_PERFC_COUNTERS                                                 \
  _PC(job_id_high_watermark)                                                   \
  _PC(pe_high_watermark)                                                       \
  _PC(jobs_launched)                                                           \
  _PC(jobs_completed)                                                          \
  _PC(pe_acquired)                                                             \
  _PC(pe_released)                                                             \
  _PC(waiting_for_job)

#ifndef NPERFC
const char *tapasco_perfc_tostring(tapasco_dev_id_t const dev_id);
#define _PC(name)                                                              \
  void tapasco_perfc_##name##_inc(tapasco_dev_id_t dev_id);                    \
  void tapasco_perfc_##name##_add(tapasco_dev_id_t dev_id, int const v);       \
  long tapasco_perfc_##name##_get(tapasco_dev_id_t dev_id);                    \
  void tapasco_perfc_##name##_set(tapasco_dev_id_t dev_id, int const v);

TAPASCO_PERFC_COUNTERS
#undef _PC
#else /* NPERFC */
static inline const char *
tapasco_perfc_tostring(tapasco_dev_id_t const dev_id) {
  return "";
}
#define _PC(name)                                                              \
  inline static void tapasco_perfc_##name##_inc(tapasco_dev_id_t dev_id) {}    \
  inline static void tapasco_perfc_##name##_add(tapasco_dev_id_t dev_id,       \
                                                int const v) {}                \
  inline static long tapasco_perfc_##name##_get(tapasco_dev_id_t dev_id) {     \
    return 0;                                                                  \
  }                                                                            \
  inline static void tapasco_perfc_##name##_set(tapasco_dev_id_t dev_id,       \
                                                int const v) {}

TAPASCO_PERFC_COUNTERS
#undef _PC
#endif /* NPERFC */
#endif /* TAPASCO_PERFC_H__ */
