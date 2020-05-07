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
//! @file	platform_errors.c
//! @brief	Error messages and codes.
//! @authors	J. Korinth (jk@esa.cs.tu-darmstadt.de)
//!
#include <platform.h>
#include <platform_errors.h>

#ifdef _X
#undef _X
#endif

#define _X(constant, code, msg) msg,
static const char *const _err_msg[] = {"success", PLATFORM_ERRORS};
#undef _X

const char *const platform_strerror(platform_res_t const res) {
  static unsigned long const _l = (unsigned long)-PERR_SENTINEL;
  unsigned long const i = (unsigned long)-res;
  if (i >= _l)
    return "unknown error";
  return _err_msg[i];
}
