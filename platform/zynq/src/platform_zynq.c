//
// Copyright (C) 2014-2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (TPC).
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
//! @version	1.3
//! @copyright  Copyright 2014-2018 J. Korinth
//!
//!		This file is part of Tapasco (TPC).
//!
//!  		Tapasco is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		Tapasco is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with Tapasco.  If not, see
//!		<http://www.gnu.org/licenses/>.
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
#include <module/zynq_platform.h>
#include <module/zynq_ioctl_cmds.h>
#include <platform.h>
#include <platform_errors.h>
#include <platform_logging.h>
#include <platform_context.h>

/******************************************************************************/

typedef struct zynq_platform {
	int 		fd_gp0_map;
	int 		fd_gp1_map;
	int 		fd_status_map;
	volatile void	*gp0_map;
	volatile void	*gp1_map;
	volatile void	*status_map;
	int		fd_control;
	platform_info_t info;
	platform_ctx_t  *ctx;
} zynq_platform_t;

static zynq_platform_t zynq_platform = {
	.fd_gp0_map    = -1,
	.fd_gp1_map    = -1,
	.fd_status_map = -1,
	.gp0_map       = NULL,
	.gp1_map       = NULL,
	.status_map    = NULL,
	.fd_control    = -1,
	.ctx           = NULL,
};

const char *const platform_waitfile(platform_ctx_t const *p)
{
	return "/dev/" ZYNQ_PLATFORM_WAITFILENAME;
}

static platform_res_t init_platform(zynq_platform_t *p)
{
	platform_res_t result;
	p->fd_gp0_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp0", O_RDWR);
	if (p->fd_gp0_map != -1) {
		p->gp0_map = mmap(
				NULL,
				ZYNQ_PLATFORM_GP0_SIZE,
				PROT_READ | PROT_WRITE | PROT_EXEC,
				MAP_SHARED,
				p->fd_gp0_map,
				0);
		if (p->gp0_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			return PERR_MMAP_DEV;
		}
	} else {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp0",
				strerror(errno));
		return PERR_OPEN_DEV;
	}

	p->fd_gp1_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp1", O_RDWR);
	if (p->fd_gp1_map != -1) {
		p->gp1_map = mmap(
				NULL,
				ZYNQ_PLATFORM_GP1_SIZE,
				PROT_READ | PROT_WRITE | PROT_EXEC,
				MAP_SHARED,
				p->fd_gp1_map,
				0);
		if (p->gp1_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			return PERR_MMAP_DEV;
		}
	} else {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp1",
				strerror(errno));
		return PERR_OPEN_DEV;
	}

	p->fd_status_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_tapasco_status", O_RDONLY);
	if (p->fd_status_map != -1) {
		p->status_map = mmap(
				NULL,
				PLATFORM_API_TAPASCO_STATUS_SIZE,
				PROT_READ,
				MAP_SHARED,
				p->fd_status_map,
				0);
		if (p->status_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			return PERR_MMAP_DEV;
		}
	} else {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_tapasco_status",
				strerror(errno));
		result = PERR_OPEN_DEV;
	}

	p->fd_control = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_control", O_RDONLY);
	if (! p->fd_control) {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_control",
				strerror(errno));
		return PERR_OPEN_DEV;
	}

	result  = platform_context_init(&p->ctx);
	if (result != PLATFORM_SUCCESS) return result;
	result = platform_info(p->ctx, &(p->info));
	if (result != PLATFORM_SUCCESS) return result;

	LOG(LPLL_INIT, "platform initialization done");
	return result;
}

static platform_res_t release_platform(zynq_platform_t *p)
{
	if (p->fd_control != -1) {
		close(p->fd_control);
		p->fd_control = -1;
	}
	if (p->fd_status_map != -1) {
		if (p->status_map != NULL && p->status_map != MAP_FAILED) {
			munmap((void *)p->status_map,
					PLATFORM_API_TAPASCO_STATUS_SIZE);
			p->status_map = NULL;
		}
		close(p->fd_status_map);
		p->fd_status_map = -1;
		p->status_map    = NULL;
	}
	if (p->fd_gp1_map != -1) {
		if (p->gp1_map != NULL && p->gp1_map != MAP_FAILED) {
			munmap((void *)p->gp1_map, ZYNQ_PLATFORM_GP1_SIZE);
			p->gp1_map = NULL;
		}
		close(p->fd_gp1_map);
		p->fd_gp1_map = -1;
		p->gp1_map    = NULL;
	}
	if (p->fd_gp0_map != -1) {
		if (p->gp0_map != NULL && p->gp0_map != MAP_FAILED) {
			munmap((void *)p->gp0_map, ZYNQ_PLATFORM_GP0_SIZE);
			p->gp0_map = NULL;
		}
		close(p->fd_gp0_map);
		p->fd_gp0_map = -1;
		p->gp0_map    = NULL;
	}
	platform_context_deinit(p->ctx);
	LOG(LPLL_INIT, "so long & thanks for all the fish, bye");
	platform_logging_exit();
	return PLATFORM_SUCCESS;
}

/******************************************************************************/

/** Enables the interrupt controllers. */
static platform_res_t enable_interrupts(zynq_platform_t *ctx)
{
	int32_t const on = -1, off = 0;
	int32_t outstanding = 0;
	uint32_t intcs = ctx->info.num_intc;
	platform_ctl_flags_t const f = PLATFORM_CTL_FLAGS_NONE;
	assert (intcs > 0 && intcs <= ZYNQ_PLATFORM_INTC_MAX_NUM);
	// TODO move code to interrupt controller unit
	LOG(LPLL_IRQ, "enabling interrupts at %d controllers", intcs);
	for (int i = 0; i < intcs; ++i) {
		platform_ctl_addr_t intc = ZYNQ_PLATFORM_INTC_BASE -
				ZYNQ_PLATFORM_GP1_BASE +
				ZYNQ_PLATFORM_INTC_OFFS * i;
		// disable all interrupts
		platform_write_ctl(ctx->ctx, intc + 0x8, sizeof(off), &off, f);
		platform_write_ctl(ctx->ctx, intc + 0x1c, sizeof(off), &off, f);
		// check & ack all outstanding IRQs
		platform_read_ctl(ctx->ctx, intc, sizeof(outstanding), &outstanding, f);
		platform_write_ctl(ctx->ctx, intc, sizeof(outstanding), &outstanding, f);
		// enable all interrupts
		platform_write_ctl(ctx->ctx, intc + 0x8, sizeof(on), &on, f);
		platform_write_ctl(ctx->ctx, intc + 0x1c, sizeof(on), &on, f);
		platform_read_ctl(ctx->ctx, intc, sizeof(outstanding), &outstanding, f);
	}
	return PLATFORM_SUCCESS;
}

platform_res_t _platform_init(const char *const version, platform_ctx_t **pctx)
{
	platform_logging_init();
	LOG(LPLL_INIT, "Platform API Version: %s", platform_version());
	if (platform_check_version(version) != PLATFORM_SUCCESS) {
		ERR("Platform API version mismatch: found %s, expected %s",
				platform_version(), version);
		return PERR_VERSION_MISMATCH;
	}

	platform_res_t const r = init_platform(&zynq_platform);
	if (r != PLATFORM_SUCCESS) {
		ERR("failed to initialize Zynq platform: %s (%d)",
				platform_strerror(r), r);
		platform_logging_exit();
	} else
		enable_interrupts(&zynq_platform);

	*pctx = zynq_platform.ctx;
	return r;
}

void platform_deinit(platform_ctx_t *ctx)
{
	LOG(LPLL_INIT, "shutting down platform");
	release_platform(&zynq_platform);
	free(ctx);
}

/******************************************************************************/
platform_res_t platform_alloc(platform_ctx_t *ctx,
		size_t const len, platform_mem_addr_t *addr,
		platform_alloc_flags_t const flags)
{
	assert(addr);
	struct zynq_ioctl_cmd_t cmd = { 0 };
	cmd.id = -1;
	cmd.length = len;
	if (ioctl(zynq_platform.fd_control, ZYNQ_IOCTL_ALLOC, &cmd)) {
		ERR("could not allocate: %s", strerror(errno));
		return PERR_MEM_ALLOC;
	}
	*addr = cmd.dma_addr;
	LOG(LPLL_MM, "len = %zu bytes, dma = 0x%08lx", len,
			(long unsigned) *addr);
	return PLATFORM_SUCCESS;
}

platform_res_t platform_dealloc(platform_ctx_t *ctx,
		platform_mem_addr_t const addr,
		platform_alloc_flags_t const flags)
{
	LOG(LPLL_MM, "dma_addr = 0x%08lx", (unsigned long) addr);
	struct zynq_ioctl_cmd_t cmd = { 0 };
	cmd.id = -1;
	cmd.dma_addr = addr;
	if (ioctl(zynq_platform.fd_control, ZYNQ_IOCTL_FREE, &cmd)) {
		ERR("could not free: %s", strerror(errno));
		return PERR_MEM_ALLOC;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_mem(platform_ctx_t const *ctx,
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void *data,
		platform_mem_flags_t const flags)
{
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long) start_addr, no_of_bytes);
	struct zynq_ioctl_cmd_t cmd = { 0 };
	cmd.id = -1;
	cmd.length = no_of_bytes;
	cmd.dma_addr = start_addr;
	cmd.data = data;
	if (ioctl(zynq_platform.fd_control, ZYNQ_IOCTL_COPYFROM, &cmd)) {
		ERR("could not read: %s", strerror(errno));
		return PERR_MEM_NO_SUCH_HANDLE; // FIXME
	}
	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_mem(platform_ctx_t const *ctx,
		platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void const*data,
		platform_mem_flags_t const flags)
{
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long) start_addr, no_of_bytes);
	struct zynq_ioctl_cmd_t cmd = { 0 };
	cmd.id = -1;
	cmd.length = no_of_bytes;
	cmd.dma_addr = start_addr;
	cmd.data = (void *)data;
	if (ioctl(zynq_platform.fd_control, ZYNQ_IOCTL_COPYTO, &cmd)) {
		ERR("could not write: %s", strerror(errno));
		return PERR_MEM_NO_SUCH_HANDLE; // FIXME
	}
	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_ctl(platform_ctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const no_of_bytes,
		void *data,
		platform_ctl_flags_t const flags)
{	
	int i;
	uint32_t *p = (uint32_t *)data;
	volatile uint32_t *r;
	LOG(LPLL_CTL, "addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)addr, no_of_bytes);

#ifndef NDEBUG
	if (no_of_bytes % 4) {
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
	else if (ISBETWEEN(addr, PLATFORM_API_TAPASCO_STATUS_BASE,
			PLATFORM_API_TAPASCO_STATUS_HIGH))
		r = (volatile uint32_t *)zynq_platform.status_map + ((addr -
				PLATFORM_API_TAPASCO_STATUS_BASE) >> 2);
	else {
		ERR("invalid platform address: 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}

	for (i = 0; i < (no_of_bytes >> 2); ++i, ++p, ++r)
		*p = *r;

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl(platform_ctx_t const *ctx,
		platform_ctl_addr_t const addr,
		size_t const no_of_bytes,
		void const*data,
		platform_ctl_flags_t const flags)
{
	int i;
	uint32_t const *p = (uint32_t const *)data;
	volatile uint32_t *r;
	LOG(LPLL_CTL, "addr = 0x%08lx, no_of_bytes = %zu",
			(unsigned long)addr, no_of_bytes);

#ifndef NDEBUG
	if (no_of_bytes % 4) {
		ERR("invalid size: %zd", no_of_bytes);
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

	for (i = 0; i < (no_of_bytes >> 2); ++i, ++p, ++r)
		*r = *p;

	return PLATFORM_SUCCESS;
}
