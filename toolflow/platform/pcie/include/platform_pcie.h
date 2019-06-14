#ifndef PLATFORM_PCIE_H__
#define PLATFORM_PCIE_H__

#include "platform_types.h"
#include "platform_devctx.h"

platform_res_t pcie_init(platform_devctx_t *devctx);
void pcie_deinit(platform_devctx_t *devctx);

#endif /* PLATFORM_PCIE_H__ */
