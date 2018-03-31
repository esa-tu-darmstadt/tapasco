#ifndef PLATFORM_ZYNQ_H__
#define PLATFORM_ZYNQ_H__

#include "platform_types.h"
#include "platform_devctx.h"

platform_res_t zynq_init(platform_devctx_t *devctx);
void zynq_exit(platform_devctx_t *devctx);

#endif /* PLATFORM_ZYNQ_H__ */
