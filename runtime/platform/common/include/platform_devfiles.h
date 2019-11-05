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
