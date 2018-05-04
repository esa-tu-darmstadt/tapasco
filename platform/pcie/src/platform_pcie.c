//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TaPaSCo).
//
// Tapasco is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tapasco is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with Tapasco.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	platform_pcie.c
//! @brief	Platform API implementation for pcie platform based on the
//!		loadable kernel module. Communicates with the pcie fabric via
//!		device driver.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <assert.h>
#include <pcie/pcie.h>
#include <tlkm_device_ioctl_cmds.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_device_operations.h>

typedef struct pcie_platform {
	volatile void			*arch_map;
	volatile void			*plat_map;
	volatile void			*status_map;
	platform_devctx_t		*devctx;
} pcie_platform_t;

static pcie_platform_t pcie_platform = {
	.arch_map       		= MAP_FAILED,
	.plat_map       		= MAP_FAILED,
	.status_map    			= MAP_FAILED,
	.devctx        			= NULL,
};

static
void pcie_unmap()
{
	if (pcie_platform.arch_map != MAP_FAILED) {
		munmap((void *)pcie_platform.arch_map, pcie_def.arch.size);
		pcie_platform.arch_map = MAP_FAILED;
	}
	if (pcie_platform.plat_map != MAP_FAILED) {
		munmap((void *)pcie_platform.plat_map, pcie_def.plat.size);
		pcie_platform.plat_map = MAP_FAILED;
	}
	if (pcie_platform.status_map != MAP_FAILED) {
		munmap((void *)pcie_platform.status_map, pcie_def.status.size);
		pcie_platform.status_map = MAP_FAILED;
	}
	DEVLOG(pcie_platform.devctx->dev_id, LPLL_DEVICE, "all I/O maps unmapped");
}

static
platform_res_t pcie_iomapping()
{
	assert(pcie_platform.devctx);
	assert(pcie_platform.devctx->fd_ctrl);
	pcie_platform.arch_map = mmap(NULL,
			pcie_def.arch.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			pcie_platform.devctx->fd_ctrl,
			pcie_def.arch.base);
	if (pcie_platform.arch_map == MAP_FAILED) {
		DEVERR(pcie_platform.devctx->dev_id, "could not map architecture: %s (%d)",
				strerror(errno), errno);
		pcie_unmap();
		return PERR_MMAP_DEV;
	}
	DEVLOG(pcie_platform.devctx->dev_id, LPLL_DEVICE, "successfully mapped architecture");

	pcie_platform.plat_map = mmap(NULL,
			pcie_def.plat.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			pcie_platform.devctx->fd_ctrl,
			pcie_def.plat.base);
	if (pcie_platform.plat_map == MAP_FAILED) {
		DEVERR(pcie_platform.devctx->dev_id, "could not map platform: %s (%d)",
				strerror(errno), errno);
		pcie_unmap();
		return PERR_MMAP_DEV;
	}
	DEVLOG(pcie_platform.devctx->dev_id, LPLL_DEVICE, "successfully mapped platform");

	pcie_platform.status_map = mmap(NULL,
			pcie_def.status.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			pcie_platform.devctx->fd_ctrl,
			pcie_def.status.base);
	if (pcie_platform.status_map == MAP_FAILED) {
		DEVERR(pcie_platform.devctx->dev_id, "could not map status core: %s (%d)",
				strerror(errno), errno);
		pcie_unmap();
		return PERR_MMAP_DEV;
	}
	DEVLOG(pcie_platform.devctx->dev_id, LPLL_DEVICE, "successfully mapped status");
	return PLATFORM_SUCCESS;
}

static
platform_res_t pcie_read_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void *data,
		platform_ctl_flags_t const flags)
{	
	int i;
	uintptr_t *p = (uintptr_t *)data;
	volatile uintptr_t *r;
	DEVLOG(ctx->dev_id, LPLL_CTL, "addr = " PRIctl ", length = %zu", addr, length);

#ifndef NDEBUG
	if (length % 4) {
		DEVERR(ctx->dev_id, "error: invalid size!");
		return PERR_CTL_INVALID_SIZE;
	}
#endif

	if (IS_BETWEEN(addr, pcie_def.arch.base, pcie_def.arch.high))
		r = (volatile uintptr_t *)pcie_platform.arch_map + ((addr - pcie_def.arch.base) / sizeof(*p));
	else if (IS_BETWEEN(addr, pcie_def.plat.base, pcie_def.plat.high))
		r = (volatile uintptr_t *)pcie_platform.plat_map + ((addr - pcie_def.plat.base) / sizeof(*p));
	else if (IS_BETWEEN(addr, pcie_def.status.base, pcie_def.status.high))
		r = (volatile uintptr_t *)pcie_platform.status_map + ((addr - pcie_def.status.base) / sizeof(*p));
	else {
		DEVERR(ctx->dev_id, "invalid platform address: " PRIctl, addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	const size_t num_transfers = (length / sizeof(*p)) + (length % sizeof(*p) ? 1 : 0);

	for (i = 0; i < num_transfers; ++i, ++p, ++r)
		*p = *r;

	return PLATFORM_SUCCESS;
}

static
platform_res_t pcie_write_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void const *data,
		platform_ctl_flags_t const flags)
{
	int i;
	uint32_t const *p = (uint32_t const *)data;
	volatile uint32_t *r;
	DEVLOG(ctx->dev_id, LPLL_CTL, "addr = 0x%08lx, length = %zu",
			(unsigned long)addr, length);

#ifndef NDEBUG
	if (length % 4) {
		DEVERR(ctx->dev_id, "invalid size: %zd", length);
		return PERR_CTL_INVALID_SIZE;
	}
#endif

	if (IS_BETWEEN(addr, pcie_def.arch.base, pcie_def.arch.high))
		r = (volatile uint32_t *)pcie_platform.arch_map + ((addr - pcie_def.arch.base) >> 2);
	else if (IS_BETWEEN(addr, pcie_def.plat.base, pcie_def.plat.high))
		r = (volatile uint32_t *)pcie_platform.plat_map + ((addr - pcie_def.plat.base) >> 2);
	else {
		DEVERR(ctx->dev_id, "invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (length >> 2); ++i, ++p, ++r)
		*r = *p;

	return PLATFORM_SUCCESS;
}

platform_res_t pcie_init(platform_devctx_t *devctx)
{
	assert(devctx);
	assert(devctx->dev_info.name);
	if (! strncmp(PCIE_CLS_NAME, devctx->dev_info.name, strlen(PCIE_CLS_NAME))) {
		DEVLOG(devctx->dev_id, LPLL_DEVICE, "matches pcie platform");
		pcie_platform.devctx = devctx;
		devctx->platform        = pcie_def;
		devctx->dops.read_ctl	= pcie_read_ctl;
		devctx->dops.write_ctl	= pcie_write_ctl;
		return pcie_iomapping();
	}
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "does not match pcie platform");
	return PERR_INCOMPATIBLE_DEVICE;
}

void pcie_deinit(platform_devctx_t *devctx)
{
	pcie_unmap();
	pcie_platform.devctx = NULL;
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "pcie device released");
}
