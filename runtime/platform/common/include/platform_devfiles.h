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
#ifndef PLATFORM_DEVFILES_H__
#define PLATFORM_DEVFILES_H__

#include "platform_types.h"
#include <stdio.h>
#include <stdlib.h>
#include <tlkm_device_ioctl_cmds.h>

#define PLATFORM_DEVFILE_MAXLEN 32
#define TLKM_CONTROL_FN "/dev/" TLKM_IOCTL_FN
#define TLKM_DEV_CONTROL_FN "/dev/" TLKM_DEV_IOCTL_FN
#define TLKM_PERFC_FN "/dev/" TLKM_DEV_PERFC_FN

static inline char *control_file(platform_dev_id_t const dev_id) {
  char *fn = (char *)calloc(sizeof(*fn), PLATFORM_DEVFILE_MAXLEN);
  if (fn)
    snprintf(fn, PLATFORM_DEVFILE_MAXLEN, TLKM_DEV_CONTROL_FN, dev_id);
  return fn;
}

#ifndef NPERFC
static inline char *perfc_file(platform_dev_id_t const dev_id) {
  char *fn = (char *)calloc(sizeof(*fn), PLATFORM_DEVFILE_MAXLEN);
  if (fn)
    snprintf(fn, PLATFORM_DEVFILE_MAXLEN, TLKM_PERFC_FN, dev_id);
  return fn;
}
#endif

#endif /* PLATFORM_DEVFILES_H__ */
