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
//! @file	tapasco_logging.c
//! @brief	Logging helper implementation. Initialization for debug output.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!

#include "tapasco_logging.h"

#ifdef NDEBUG
int tapasco_logging_init(void) { return 1; }
void tapasco_logging_deinit(void) {}
#else

#include <stdlib.h>

static FILE *logfile = 0;

int tapasco_logging_init(void) {
  static int is_initialized = 0;
  if (!is_initialized) {
    is_initialized = 1;

    char const *lgf = getenv("LIBTAPASCO_LOGFILE");
    logfile = lgf ? fopen(lgf, "w+") : 0;

    if (lgf && !logfile) {
      logfile = 0;
      WRN("could not open logfile '%s'!\n", lgf);
    }

    if (logfile) {
      log_set_quiet(1);
      log_set_fp(logfile);
    }
  }
  return 1;
}

void tapasco_logging_deinit(void) {
  log_set_fp(NULL);

  if (logfile != NULL && logfile != stderr) {
    fflush(logfile);
    fclose(logfile);
  }
  logfile = NULL;
}

#endif