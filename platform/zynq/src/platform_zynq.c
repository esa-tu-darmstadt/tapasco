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
//! @file	platform_zynq.c
//! @brief	Platform API implementation for zynq platform based on the
//!		loadable kernel module. Communicates with the zynq fabric via
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
#include <zynq/zynq.h>
#include <tlkm_device_ioctl_cmds.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_device_operations.h>

typedef struct zynq_platform {
	volatile void			*arch_map;
	volatile void			*plat_map;
	volatile void			*status_map;
	platform_devctx_t		*devctx;
} zynq_platform_t;

static zynq_platform_t zynq_platform = {
	.arch_map       		= MAP_FAILED,
	.plat_map       		= MAP_FAILED,
	.status_map    			= MAP_FAILED,
	.devctx        			= NULL,
};

static
void zynq_unmap()
{
	if (zynq_platform.arch_map != MAP_FAILED) {
		munmap((void *)zynq_platform.arch_map, zynq_def.arch.size);
		zynq_platform.arch_map = MAP_FAILED;
	}
	if (zynq_platform.plat_map != MAP_FAILED) {
		munmap((void *)zynq_platform.plat_map, zynq_def.plat.size);
		zynq_platform.plat_map = MAP_FAILED;
	}
	if (zynq_platform.status_map != MAP_FAILED) {
		munmap((void *)zynq_platform.status_map, zynq_def.status.size);
		zynq_platform.status_map = MAP_FAILED;
	}
	DEVLOG(zynq_platform.devctx->dev_id, LPLL_DEVICE, "all I/O maps unmapped");
}

static
platform_res_t zynq_iomapping()
{
	assert(zynq_platform.devctx);
	assert(zynq_platform.devctx->fd_ctrl);
	zynq_platform.arch_map = mmap(NULL,
			zynq_def.arch.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			zynq_def.arch.base);
	if (zynq_platform.arch_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map GP0: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}

	zynq_platform.plat_map = mmap(NULL,
			zynq_def.plat.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			zynq_def.plat.base);
	if (zynq_platform.plat_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map GP1: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}

	zynq_platform.status_map = mmap(NULL,
			zynq_def.status.size,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			zynq_def.status.base);
	if (zynq_platform.status_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map status core: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}
	return PLATFORM_SUCCESS;
}

static
platform_res_t zynq_read_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void *data,
		platform_ctl_flags_t const flags)
{	
	int i;
	uint32_t *p = (uint32_t *)data;
	volatile uint32_t *r;
	DEVLOG(ctx->dev_id, LPLL_CTL, "addr = 0x%08lx, length = %zu",
			(unsigned long)addr, length);

#ifndef NDEBUG
	if (length % 4) {
		DEVERR(ctx->dev_id, "error: invalid size!");
		return PERR_CTL_INVALID_SIZE;
	}
#endif

	if (IS_BETWEEN(addr, zynq_def.arch.base, zynq_def.arch.high))
		r = (volatile uint32_t *)zynq_platform.arch_map + ((addr - zynq_def.arch.base) >> 2);
	else if (IS_BETWEEN(addr, zynq_def.plat.base, zynq_def.plat.high))
		r = (volatile uint32_t *)zynq_platform.plat_map + ((addr - zynq_def.plat.base) >> 2);
	else if (IS_BETWEEN(addr, zynq_def.status.base,
			zynq_def.status.high))
		r = (volatile uint32_t *)zynq_platform.status_map + ((addr - zynq_def.status.base) >> 2);
	else {
		DEVERR(ctx->dev_id, "invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (length >> 2); ++i, ++p, ++r)
		*p = *r;

	return PLATFORM_SUCCESS;
}

static
platform_res_t zynq_write_ctl(platform_devctx_t const *ctx,
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

	if (IS_BETWEEN(addr, zynq_def.arch.base, zynq_def.arch.high))
		r = (volatile uint32_t *)zynq_platform.arch_map + ((addr - zynq_def.arch.base) >> 2);
	else if (IS_BETWEEN(addr, zynq_def.plat.base, zynq_def.plat.high))
		r = (volatile uint32_t *)zynq_platform.plat_map + ((addr - zynq_def.plat.base) >> 2);
	else {
		DEVERR(ctx->dev_id, "invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (length >> 2); ++i, ++p, ++r)
		*r = *p;

	return PLATFORM_SUCCESS;
}

platform_res_t zynq_init(platform_devctx_t *devctx)
{
	assert(devctx);
	assert(devctx->dev_info.name);
	if (! strncmp(ZYNQ_CLASS_NAME, devctx->dev_info.name, strlen(ZYNQ_CLASS_NAME))) {
		DEVLOG(devctx->dev_id, LPLL_DEVICE, "matches zynq platform");
		zynq_platform.devctx = devctx;
		devctx->platform        = zynq_def;
		devctx->dops.read_ctl	= zynq_read_ctl;
		devctx->dops.write_ctl	= zynq_write_ctl;
		return zynq_iomapping();
	}
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "does not match zynq platform");
	return PERR_INCOMPATIBLE_DEVICE;
}

void zynq_deinit(platform_devctx_t *devctx)
{
	zynq_unmap();
	zynq_platform.devctx = NULL;
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "zynq device released");
}
