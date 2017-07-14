//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
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
//! @version	1.2
//! @copyright  Copyright 2014, 2015 J. Korinth
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
#include "platform_logging.h"

/******************************************************************************/

static struct zynq_platform_t {
	int		fd_wait;
	int 		fd_gp0_map;
	int 		fd_gp1_map;
	int 		fd_status_map;
	volatile void	*gp0_map;
	volatile void	*gp1_map;
	volatile void	*status_map;
	int		fd_control;
} zynq_platform = {
	.fd_wait       = -1,
	.fd_gp0_map    = -1,
	.fd_gp1_map    = -1,
	.fd_status_map = -1,
	.gp0_map       = NULL,
	.gp1_map       = NULL,
	.status_map    = NULL,
	.fd_control    = -1,
};

static platform_res_t init_platform(struct zynq_platform_t *p)
{
	platform_res_t result = PLATFORM_SUCCESS;
	p->fd_wait     = open(ZYNQ_PLATFORM_WAITFILENAME, O_WRONLY);
	if (p->fd_wait == -1) {
		ERR("could not open device file: %s", ZYNQ_PLATFORM_WAITFILENAME);
		result = PERR_OPEN_DEV;
	}
	p->fd_gp0_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp0", O_RDWR);
	if (p->fd_gp0_map != -1) {
		p->gp0_map = mmap(
				NULL,
				129 * 0x10000UL,
				PROT_READ | PROT_WRITE | PROT_EXEC,
				MAP_SHARED,
				p->fd_gp0_map,
				0);
		if (p->gp0_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			result = PERR_MMAP_DEV;
		}
	} else {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp0",
				strerror(errno));
		result = PERR_OPEN_DEV;
	}

	p->fd_gp1_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp1", O_RDWR);
	if (p->fd_gp1_map != -1) {
		p->gp1_map = mmap(
				NULL,
				0x100000UL,
				PROT_READ | PROT_WRITE | PROT_EXEC,
				MAP_SHARED,
				p->fd_gp1_map,
				0);
		if (p->gp1_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			result = PERR_MMAP_DEV;
		}
	} else {
		ERR("could not open '%s': %s",
				"/dev/" ZYNQ_PLATFORM_DEVFILENAME "_gp1",
				strerror(errno));
		result = PERR_OPEN_DEV;
	}

	p->fd_status_map = open("/dev/" ZYNQ_PLATFORM_DEVFILENAME "_tapasco_status", O_RDONLY);
	if (p->fd_status_map != -1) {
		p->status_map = mmap(
				NULL,
				0x1000,
				PROT_READ,
				MAP_SHARED,
				p->fd_status_map,
				0);
		if (p->status_map == MAP_FAILED) {
			ERR("could not mmap regmap: %s", strerror(errno));
			result = PERR_MMAP_DEV;
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
		result = PERR_OPEN_DEV;
	}
	LOG(LPLL_INIT, "platform initialization done");
	return result;
}

static platform_res_t release_platform(struct zynq_platform_t *p)
{
	if (p->fd_control != -1) {
		close(p->fd_control);
		p->fd_control = -1;
	}
	if (p->fd_status_map != -1) {
		if (p->status_map != NULL && p->status_map != MAP_FAILED) {
			munmap((void *)p->status_map, 0x1000);
			p->status_map = NULL;
		}
		close(p->fd_status_map);
		p->fd_status_map = -1;
		p->status_map    = NULL;
	}
	if (p->fd_gp1_map != -1) {
		if (p->gp1_map != NULL && p->gp1_map != MAP_FAILED) {
			munmap((void *)p->gp1_map, 0x100000UL);
			p->gp1_map = NULL;
		}
		close(p->fd_gp1_map);
		p->fd_gp1_map = -1;
		p->gp1_map    = NULL;
	}
	if (p->fd_gp0_map != -1) {
		if (p->gp0_map != NULL && p->gp0_map != MAP_FAILED) {
			munmap((void *)p->gp0_map, 48 * 0x10000UL);
			p->gp0_map = NULL;
		}
		close(p->fd_gp0_map);
		p->fd_gp0_map = -1;
		p->gp0_map    = NULL;
	}
	if (p->fd_wait != -1) {
		close(p->fd_wait);
		p->fd_wait = -1;
	}
	LOG(LPLL_INIT, "so long & thanks for all the fish, bye");
	platform_logging_exit();
	return PLATFORM_SUCCESS;
}

/******************************************************************************/

/** Enables the interrupt controllers. */
static platform_res_t enable_interrupts(void)
{
	int32_t const on = -1, off = 0;
	int32_t outstanding = 0;
	uint32_t intcs = 1;
	platform_read_ctl(platform_address_get_special_base(
			PLATFORM_SPECIAL_CTL_STATUS) + 0x4,
			4, &intcs, PLATFORM_CTL_FLAGS_NONE);
	assert (intcs > 0 && intcs <= ZYNQ_PLATFORM_INTC_NUM);
	LOG(LPLL_IRQ, "enabling interrupts at %d controllers", intcs);
	for (int i = 0; i < intcs; ++i) {
		platform_ctl_addr_t intc = ZYNQ_PLATFORM_INTC_BASE + ZYNQ_PLATFORM_INTC_OFFS * i;
		// disable all interrupts
		platform_write_ctl(intc + 0x8, sizeof(off), &off, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc + 0x1c, sizeof(off), &off, PLATFORM_CTL_FLAGS_NONE);
		// check & ack all outstanding IRQs
		platform_read_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
		// enable all interrupts
		platform_write_ctl(intc + 0x8, sizeof(on), &on, PLATFORM_CTL_FLAGS_NONE);
		platform_write_ctl(intc + 0x1c, sizeof(on), &on, PLATFORM_CTL_FLAGS_NONE);
		platform_read_ctl(intc, sizeof(outstanding), &outstanding, PLATFORM_CTL_FLAGS_NONE);
	}
	return PLATFORM_SUCCESS;
}

platform_res_t _platform_init(const char *const version)
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
		ERR("failed with error: %s\n", platform_strerror(r));
		platform_logging_exit();
	} else
		enable_interrupts();
	return r;
}

void platform_deinit(void)
{
	LOG(LPLL_INIT, "shutting down platform");
	release_platform(&zynq_platform);
}

/******************************************************************************/
platform_res_t platform_alloc(size_t const len, platform_mem_addr_t *addr,
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

platform_res_t platform_dealloc(platform_mem_addr_t const addr,
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

platform_res_t platform_read_mem(platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void *data,
		platform_mem_flags_t const flags)
{
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu, data = 0x%08lx",
			(unsigned long) start_addr, no_of_bytes,
			(unsigned long) data);
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

platform_res_t platform_write_mem(platform_mem_addr_t const start_addr,
		size_t const no_of_bytes, void const*data,
		platform_mem_flags_t const flags)
{
	LOG(LPLL_MEM, "start_addr = 0x%08lx, no_of_bytes = %zu, data = 0x%08lx",
			(unsigned long) start_addr, no_of_bytes, (unsigned long)data);
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

static inline
platform_res_t platform_check_ctl_addr(platform_ctl_addr_t const addr)
{
	// FIXME remove magic literals
	if (!((addr >= 0x43C00000 && addr < 0x44400000) ||
			(addr >= 0x77770000 && addr < 0x77771000) ||
			(addr >= 0x81800000 && addr < 0x81850000))) {
		ERR("invalid start_addr: start_addr = 0x%08lx", (unsigned long)addr);
		return PERR_CTL_INVALID_ADDRESS;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void *data,
		platform_ctl_flags_t const flags)
{	
	int i;
	uint32_t *p = (uint32_t *)data;
	volatile uint32_t *r;
	platform_res_t res;
	LOG(LPLL_CTL, "start_addr = 0x%08lx, no_of_bytes = %zu, data = 0x%08lx",
			(unsigned long)start_addr, no_of_bytes, (unsigned long)data);

	res = platform_check_ctl_addr(start_addr);
	if (res != PLATFORM_SUCCESS)
		return res;

	if (no_of_bytes % 4) {
		ERR("error: invalid size!");
		return PERR_CTL_INVALID_SIZE;
	}
	if (start_addr >= 0x81800000)
		r = (volatile uint32_t *)zynq_platform.gp1_map +
				((start_addr - 0x81800000) >> 2);
	else if (start_addr >= 0x77770000)
		r = (volatile uint32_t *)zynq_platform.status_map +
				((start_addr - 0x77770000) >> 2);
	else
		r = (volatile uint32_t *)zynq_platform.gp0_map +
				((start_addr - 0x43C00000) >> 2);
	for (i = 0; i < (no_of_bytes >> 2); ++i, ++p, ++r)
		*p = *r;

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl(
		platform_ctl_addr_t const start_addr,
		size_t const no_of_bytes,
		void const*data,
		platform_ctl_flags_t const flags)
{
	int i;
	uint32_t const *p = (uint32_t const *)data;
	volatile uint32_t *r;
	platform_res_t res;
	LOG(LPLL_CTL, "start_addr = 0x%08lx, no_of_bytes = %zu, data = 0x%08lx",
			(unsigned long)start_addr, no_of_bytes, (unsigned long)data);

	res = platform_check_ctl_addr(start_addr);
	if (res != PLATFORM_SUCCESS)
		return res;

	if (no_of_bytes % 4) {
		ERR("invalid size: %zd", no_of_bytes);
		return PERR_CTL_INVALID_SIZE;
	}
	if (start_addr >= 0x81800000)
		r = (volatile uint32_t *)zynq_platform.gp1_map +
				((start_addr - 0x81800000) >> 2);
	else
		r = (volatile uint32_t *)zynq_platform.gp0_map +
				((start_addr - 0x43C00000) >> 2);
	for (i = 0; i < (no_of_bytes >> 2); ++i, ++p, ++r)
		*r = *p;

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl_and_wait(
		platform_ctl_addr_t const w_addr,
		size_t const w_no_of_bytes,
		void const *w_data,
		uint32_t const event,
		platform_ctl_flags_t const flags)
{
	platform_res_t res = platform_write_ctl(w_addr, w_no_of_bytes, w_data,
			PLATFORM_CTL_FLAGS_NONE);
	if (res != PLATFORM_SUCCESS) return res;
	return platform_wait_for_irq(event);
}

platform_res_t platform_wait_for_irq(const uint32_t inst)
{
	int retval = write(zynq_platform.fd_wait, &inst, sizeof(inst));
	if (retval < 0)
		WRN("waiting for %u failed: %d", inst, retval);
	return retval < 0 ? PERR_IRQ_WAIT : PLATFORM_SUCCESS;
}

platform_res_t platform_register_irq_callback(platform_irq_callback_t cb)
{
	return PERR_NOT_IMPLEMENTED;
}

platform_res_t platform_stop(const int result)
{
	return PERR_NOT_IMPLEMENTED;
}
