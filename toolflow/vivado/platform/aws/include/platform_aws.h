#ifndef PLATFORM_AWS_H__
#define PLATFORM_AWS_H__

#include "platform_types.h"
#include "platform_devctx.h"

platform_res_t pcie_init(platform_devctx_t *devctx);
void pcie_deinit(platform_devctx_t *devctx);

#endif /* PLATFORM_AWS_H__ */
