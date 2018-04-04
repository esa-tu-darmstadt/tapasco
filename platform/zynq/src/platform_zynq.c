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
//! @brief	Platform API implementation for Zynq platform based on the
//!		loadable kernel module. Communicates with the Zynq fabric via 
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
#include <zynq/zynq_platform.h>
#include <tlkm_device_ioctl_cmds.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_device_operations.h>

typedef struct zynq_platform {
	volatile void		*gp0_map;
	volatile void		*gp1_map;
	volatile void		*status_map;
	platform_devctx_t	*devctx;
} zynq_platform_t;

static zynq_platform_t zynq_platform = {
	.gp0_map       		= MAP_FAILED,
	.gp1_map       		= MAP_FAILED,
	.status_map    		= MAP_FAILED,
	.devctx        		= NULL,
};

static
void zynq_unmap()
{
	if (zynq_platform.gp0_map != MAP_FAILED) {
		munmap((void *)zynq_platform.gp0_map, ZYNQ_PLATFORM_GP0_SIZE);
	}
	if (zynq_platform.gp1_map != MAP_FAILED) {
		munmap((void *)zynq_platform.gp1_map, ZYNQ_PLATFORM_GP1_SIZE);
	}
	if (zynq_platform.status_map != MAP_FAILED) {
		munmap((void *)zynq_platform.status_map, ZYNQ_PLATFORM_STATUS_SIZE);
	}
	DEVLOG(zynq_platform.devctx->dev_id, LPLL_DEVICE, "all I/O maps unmapped");
}

static
platform_res_t zynq_iomapping()
{
	assert(zynq_platform.devctx);
	assert(zynq_platform.devctx->fd_ctrl);
	zynq_platform.gp0_map = mmap(NULL,
			ZYNQ_PLATFORM_GP0_SIZE,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			ZYNQ_PLATFORM_GP0_BASE);
	if (zynq_platform.gp0_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map GP0: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}

	zynq_platform.gp1_map = mmap(NULL,
			ZYNQ_PLATFORM_GP0_SIZE,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			ZYNQ_PLATFORM_GP1_BASE);
	if (zynq_platform.gp1_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map GP1: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}

	zynq_platform.status_map = mmap(NULL,
			ZYNQ_PLATFORM_STATUS_SIZE,
			PROT_READ | PROT_WRITE | PROT_EXEC,
			MAP_SHARED,
			zynq_platform.devctx->fd_ctrl,
			ZYNQ_PLATFORM_STATUS_BASE);
	if (zynq_platform.status_map == MAP_FAILED) {
		DEVERR(zynq_platform.devctx->dev_id, "could not map status core: %s (%d)",
				strerror(errno), errno);
		zynq_unmap();
		return PERR_MMAP_DEV;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t zynq_init(platform_devctx_t *devctx)
{
	assert(devctx);
	assert(devctx->dev_info.name);
	if (! strncmp(ZYNQ_NAME, devctx->dev_info.name, strlen(ZYNQ_NAME))) {
		DEVLOG(devctx->dev_id, LPLL_DEVICE, "device #%03u matches Zynq platform");
		zynq_platform.devctx = devctx;
		return zynq_iomapping();
	}
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "does not match Zynq platform");
	return PERR_INCOMPATIBLE_DEVICE;
}

void zynq_exit(platform_devctx_t *devctx)
{
	zynq_unmap();
	zynq_platform.devctx = NULL;
	DEVLOG(devctx->dev_id, LPLL_DEVICE, "Zynq device released");
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
	LOG(LPLL_CTL, "addr = 0x%08lx, length = %zu",
			(unsigned long)addr, length);

#ifndef NDEBUG
	if (length % 4) {
		ERR("error: invalid size!");
		return PERR_CTL_INVALID_SIZE;
	}
#endif

	if (ISBETWEEN(addr, ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_HIGH))
		r = (volatile uint32_t *)zynq_platform.gp0_map +
				((addr - ZYNQ_PLATFORM_GP0_BASE) >> 2);
	else if (ISBETWEEN(addr, ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_HIGH))
		r = (volatile uint32_t *)zynq_platform.gp1_map +
				((addr - ZYNQ_PLATFORM_GP1_BASE) >> 2);
	else if (ISBETWEEN(addr, ZYNQ_PLATFORM_STATUS_BASE,
			ZYNQ_PLATFORM_STATUS_HIGH))
		r = (volatile uint32_t *)zynq_platform.status_map + ((addr -
				ZYNQ_PLATFORM_STATUS_BASE) >> 2);
	else {
		ERR("invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (length >> 2); ++i, ++p, ++r)
		*p = *r;

	return PLATFORM_SUCCESS;
}

platform_res_t zynq_write_ctl(platform_devctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const length,
		void const *data,
		platform_ctl_flags_t const flags)
{
	int i;
	uint32_t const *p = (uint32_t const *)data;
	volatile uint32_t *r;
	LOG(LPLL_CTL, "addr = 0x%08lx, length = %zu",
			(unsigned long)addr, length);

#ifndef NDEBUG
	if (length % 4) {
		ERR("invalid size: %zd", length);
		return PERR_CTL_INVALID_SIZE;
	}
#endif

	if (ISBETWEEN(addr, ZYNQ_PLATFORM_GP0_BASE, ZYNQ_PLATFORM_GP0_HIGH))
		r = (volatile uint32_t *)zynq_platform.gp0_map +
				((addr - ZYNQ_PLATFORM_GP0_BASE) >> 2);
	else if (ISBETWEEN(addr, ZYNQ_PLATFORM_GP1_BASE, ZYNQ_PLATFORM_GP1_HIGH))
		r = (volatile uint32_t *)zynq_platform.gp1_map +
				((addr - ZYNQ_PLATFORM_GP1_BASE) >> 2);
	else {
		ERR("invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (length >> 2); ++i, ++p, ++r)
		*r = *p;

	return PLATFORM_SUCCESS;
}

static const struct platform_device_operations _zynq_dops = {
	.alloc		= default_alloc,
	.dealloc	= default_dealloc,
	.read_mem	= default_read_mem,
	.write_mem	= default_write_mem,
	.read_ctl	= zynq_read_ctl,
	.write_ctl	= zynq_write_ctl,
};
