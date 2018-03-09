//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
//
// This file is part of TaPaSCo (TAPASCO).
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
#include <iostream>
#include <ctime>			// to convert time_t to string
#include <climits>			// to convert time_t to string
#include <chrono>			// for easier time-measurements
#include <string>

extern "C" {
	#include <errno.h>			// error types
	#include <unistd.h>			// read write calls, Posix Flags
	#include <fcntl.h>			// open call
	#include <sys/ioctl.h>		// to ioctl the device node

	#include "dma_ioctl_calls.h"
	#include "user_ioctl_calls.h"

	#include <platform_logging.h>
	#include <platform_errors.h>
	#include <platform_context.h>
	#include <platform.h>
}

#include "buddy_allocator.hpp"

#define INPUT_TESTS			0

static const char *dma_dev_path[4] = {
	"/dev/FFLINK_DMA_DEVICE_0",
	"/dev/FFLINK_DMA_DEVICE_1",
	"/dev/FFLINK_DMA_DEVICE_2",
	"/dev/FFLINK_DMA_DEVICE_3"
};

static const char *user_dev_path = "/dev/FFLINK_USER_DEVICE_0";

#define ALLOC_SMALL_OFFSET 		0x20000000
#define ALLOC_MEDIUM_OFFSET 		0x30000000
#define ALLOC_LARGE_OFFSET 		0x60000000

#define ALLOC_SMALL_TOTAL 		33554432	// 32 MB
#define ALLOC_MEDIUM_TOTAL	 	536870912	//512 MB
#define ALLOC_LARGE_TOTAL 		3221225472	//  3 GB

#define ALLOC_START_ORDER		10			//  1 KB
#define ALLOC_SMALL_ORDER		15			// 32 KB
#define ALLOC_MEDIUM_ORDER		21			//  2 MB
#define ALLOC_LARGE_ORDER		31			//  2 GB
#define ALLOC_START_MAX			(1U << ALLOC_START_ORDER)
#define ALLOC_SMALL_MAX			(1U << ALLOC_SMALL_ORDER)
#define ALLOC_MEDIUM_MAX		(1U << ALLOC_MEDIUM_ORDER)
#define ALLOC_LARGE_MAX			(1U << ALLOC_LARGE_ORDER)

#define ADDRESS_MAX 			0x04000000
#define USER_ADDRESS_OFFSET 		0x02000000
#define SLOT_OFFSET 			0x00010000
#define REGION_OFFSET 			0x00001000

#define MAX_SLOTS			144 // 128 functions + 16 infos
#define MAX_REGIONS			16

#define HW_ID_MAGIC			0xE5AE1337
#define HW_ID_ADDR			0x00800000
#define HW_ID_MAX_OFFSET		0x00000004

#define NUM_DMA_DEV			1
#define NUM_USER_DEV			1

#define INTC0_ADDRESS			0x00400000
#define INTC1_ADDRESS			0x00410000
#define INTC2_ADDRESS			0x00420000
#define INTC3_ADDRESS			0x00430000

#define ATSPRI_ADDRESS			0x00390000

static struct {
	platform_ctx_t			*ctx;
	int				fd_dma_engine[NUM_DMA_DEV];
	int				fd_user[NUM_USER_DEV];
	int				opened_dma_devs  = 0;
	int				opened_user_devs = 0;
	buddy_allocator 		*ba_small;
	buddy_allocator		 	*ba_medium;
	buddy_allocator		 	*ba_large;
} pcie_platform;

static pthread_mutex_t ba_small_lock 	= PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP;
static pthread_mutex_t ba_medium_lock 	= PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP;
static pthread_mutex_t ba_large_lock 	= PTHREAD_ADAPTIVE_MUTEX_INITIALIZER_NP;

platform_res_t helper_init(int* fd, const string& path)
{
	*fd = open(path.c_str(), O_RDWR | O_SYNC);
	LOG(LPLL_INIT, "Opened %s with return value %d", path.c_str(), *fd);
	if(*fd < 0) {
		ERR("Could not open %s",path.c_str());
		return (platform_res_t) PERR_OPEN_DEV;
	}
	return PLATFORM_SUCCESS;
}

platform_res_t _platform_init(const char *const version, platform_ctx_t **ctx)
{
	uint32_t data = 0;
	platform_res_t res;

	platform_logging_init();
	LOG(LPLL_INIT, "version: %s, expected version: %s", platform_version(), version);
	if (platform_check_version(version) != PLATFORM_SUCCESS) {
		ERR("version mismatch: found %s, expected %s", platform_version(), version);
		return PERR_VERSION_MISMATCH;
	}

<<<<<<< HEAD:platform/vc709/src/platform_vc709.cpp
	platform_res_t const r = platform_context_init(ctx);
	if (r != PLATFORM_SUCCESS) {
		ERR("could not initialize platform context: %s (%d)", platform_strerror(r), r);
		return r;
	}
	vc709_platform.ctx = *ctx;

	if(helper_init(&vc709_platform.fd_dma_engine[0], dma_dev_path[0]) != PLATFORM_SUCCESS)
=======
	if(helper_init(&pcie_platform.fd_dma_engine[0], dma_dev_path[0]) != PLATFORM_SUCCESS)
>>>>>>> 2018.1:platform/pcie/src/platform_pcie.cpp
		return (platform_res_t) PERR_OPEN_DEV;
	pcie_platform.opened_dma_devs++;

	if(helper_init(&pcie_platform.fd_user[0], user_dev_path) != PLATFORM_SUCCESS)
		return (platform_res_t) PERR_OPEN_DEV;
	pcie_platform.opened_user_devs++;

	res = platform_read_ctl(*ctx, (platform_ctl_addr_t) HW_ID_ADDR + HW_ID_MAX_OFFSET, 4, &data, PLATFORM_CTL_FLAGS_NONE);
	if(res != PLATFORM_SUCCESS || data > NUM_USER_DEV) {
		ERR("Wrong status core setting - irq_cores are: %X", data);
		return (platform_res_t) PERR_OPEN_DEV;
	}

	pcie_platform.ba_small = new buddy_allocator(ALLOC_SMALL_OFFSET, ALLOC_SMALL_TOTAL, ALLOC_START_ORDER, ALLOC_SMALL_ORDER);
	pcie_platform.ba_medium = new buddy_allocator(ALLOC_MEDIUM_OFFSET, ALLOC_MEDIUM_TOTAL, ALLOC_SMALL_ORDER + 1, ALLOC_MEDIUM_ORDER);
	pcie_platform.ba_large = new buddy_allocator(ALLOC_LARGE_OFFSET, ALLOC_LARGE_TOTAL, ALLOC_MEDIUM_ORDER + 1, ALLOC_LARGE_ORDER);

	return PLATFORM_SUCCESS;
}

void platform_deinit(platform_ctx_t *ctx)
{
	LOG(LPLL_INIT, "Close devices");

	for(int i = 0; i < pcie_platform.opened_user_devs; i++)
		close(pcie_platform.fd_user[i]);

	for(int i = 0; i < pcie_platform.opened_dma_devs; i++)
		close(pcie_platform.fd_dma_engine[i]);

	delete(pcie_platform.ba_small);
	delete(pcie_platform.ba_medium);
	delete(pcie_platform.ba_large);

	platform_context_deinit(ctx);
	platform_logging_exit();
}

platform_res_t platform_alloc(platform_ctx_t *ctx, size_t const len, platform_mem_addr_t *addr, platform_alloc_flags_t const flags)
{
	if(len > 0 && len <= ALLOC_SMALL_MAX) {
		LOG(LPLL_MEM, "Using small allocator");
		pthread_mutex_lock(&ba_small_lock);
		*addr = pcie_platform.ba_small->alloc_Mem(len);
		pthread_mutex_unlock(&ba_small_lock);
	} else if(len <= ALLOC_MEDIUM_MAX) {
		LOG(LPLL_MEM, "Using medium allocator");
		pthread_mutex_lock(&ba_medium_lock);
		*addr = pcie_platform.ba_medium->alloc_Mem(len);
		pthread_mutex_unlock(&ba_medium_lock);
	} else if(len <= ALLOC_LARGE_MAX) {
		LOG(LPLL_MEM, "Using large allocator");
		pthread_mutex_lock(&ba_large_lock);
		*addr = pcie_platform.ba_large->alloc_Mem(len);
		pthread_mutex_unlock(&ba_large_lock);
	} else {
		WRN("Invalid size for memory allocation (%lu)", len);
		return (platform_res_t) PERR_MEM_ALLOC_INVALID_SIZE;
	}

	if(*addr == 0) {
		WRN("Out of memory");
		return (platform_res_t) PERR_MEM_ALLOC;
	}

	LOG(LPLL_MEM, "Got address %X with size %lu", *addr, len);
	return PLATFORM_SUCCESS;
}

platform_res_t platform_dealloc(platform_ctx_t *ctx, platform_mem_addr_t const addr, platform_alloc_flags_t const flags)
{
	LOG(LPLL_MEM, "Remove address %X ", addr);

	if(addr >= ALLOC_SMALL_OFFSET && addr <= ALLOC_SMALL_OFFSET + ALLOC_SMALL_TOTAL) {
		LOG(LPLL_MEM, "in small allocator");
		pthread_mutex_lock(&ba_small_lock);
		pcie_platform.ba_small->dealloc_Mem(addr);
		pthread_mutex_unlock(&ba_small_lock);
	} else if(addr >= ALLOC_MEDIUM_OFFSET && addr <= ALLOC_MEDIUM_OFFSET + ALLOC_MEDIUM_TOTAL) {
		LOG(LPLL_MEM, "in medium allocator");
		pthread_mutex_lock(&ba_medium_lock);
		pcie_platform.ba_medium->dealloc_Mem(addr);
		pthread_mutex_unlock(&ba_medium_lock);
	} else if(addr >= ALLOC_LARGE_OFFSET && addr <= ALLOC_LARGE_OFFSET + ALLOC_LARGE_TOTAL) {
		LOG(LPLL_MEM, "in large allocator");
		pthread_mutex_lock(&ba_large_lock);
		pcie_platform.ba_large->dealloc_Mem(addr);
		pthread_mutex_unlock(&ba_large_lock);
	} else {
		WRN("Invalid memory address %X", addr);
		return (platform_res_t) PERR_MEM_ALLOC;
	}

	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_mem(platform_ctx_t *ctx, platform_mem_addr_t const start_addr, size_t const no_of_bytes, void *data, platform_mem_flags_t const flags)
{
	int err;
	struct dma_ioctl_params params { 0 };
	params.host_addr = (uint64_t) data;
	params.fpga_addr = (uint64_t) start_addr;
	params.btt = (uint32_t) no_of_bytes;

#if (INPUT_TESTS == 1)
	if(params.fpga_addr < ALLOC_SMALL_OFFSET || params.fpga_addr > ALLOC_LARGE_OFFSET + ALLOC_LARGE_TOTAL || params.fpga_addr & (ALLOC_START_MAX - 1)) {
		WRN("FPGA address is not valid %lX",params.fpga_addr);
		return (platform_res_t) PERR_CTL_INVALID_ADDRESS;
	}

	if(params.btt > ALLOC_LARGE_MAX) {
		WRN("Transfer size exceeds max. contigious size (%d vs. %d)", params.btt, ALLOC_LARGE_MAX);
		return (platform_res_t) PERR_CTL_INVALID_SIZE;
	}
#endif

	LOG(LPLL_DMA, "Fpga addr %lX to host address %lX with length %d", params.fpga_addr, params.host_addr, params.btt);
	err = ioctl(pcie_platform.fd_dma_engine[0], IOCTL_CMD_DMA_READ_BUF, &params);

	if(err) {
		WRN("Ioctl went wrong with error %d", err);
		return (platform_res_t) PERR_DMA_SYS_CALL;
	}

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_mem(platform_ctx_t *ctx, platform_mem_addr_t const start_addr, size_t const no_of_bytes, void const*data, platform_mem_flags_t const flags)
{
	int err;
	struct dma_ioctl_params params { 0 };
	params.host_addr = (uint64_t) data;
	params.fpga_addr = (uint64_t) start_addr;
	params.btt = (uint32_t) no_of_bytes;

#if (INPUT_TESTS == 1)
	if(params.fpga_addr < ALLOC_SMALL_OFFSET || params.fpga_addr > ALLOC_LARGE_OFFSET + ALLOC_LARGE_TOTAL || params.fpga_addr & (ALLOC_START_MAX - 1)) {
		WRN("FPGA address is not valid %lX",params.fpga_addr);
		return (platform_res_t) PERR_DMA_INVALID_ADDRESS;
	}

	if(params.btt > ALLOC_LARGE_MAX) {
		WRN("Transfer size exceeds max. contigious size (%d vs. %d)", params.btt, ALLOC_LARGE_MAX);
		return (platform_res_t) PERR_DMA_INVALID_SIZE;
	}
#endif

	LOG(LPLL_DMA, "Fpga addr %lX to host address %lX with length %d", params.fpga_addr, params.host_addr, params.btt);
	err = ioctl(pcie_platform.fd_dma_engine[0], IOCTL_CMD_DMA_WRITE_BUF, &params);

	if(err) {
		WRN("Ioctl went wrong with error %d", err);
		return (platform_res_t) PERR_DMA_SYS_CALL;
	}

	return PLATFORM_SUCCESS;
}

platform_res_t platform_read_ctl(platform_ctx_t *ctx, platform_ctl_addr_t const start_addr, size_t const no_of_bytes, void *data, platform_ctl_flags_t const flags)
{
	int err;
	struct user_rw_params params { 0 };
	if (start_addr == INTC0_ADDRESS || start_addr == INTC1_ADDRESS || start_addr == INTC2_ADDRESS || start_addr == INTC3_ADDRESS || (start_addr & 0xFFFF0000) == ATSPRI_ADDRESS || flags == PLATFORM_CTL_FLAGS_RAW)
	  params.fpga_addr = start_addr;
	else
	  params.fpga_addr = start_addr + USER_ADDRESS_OFFSET;
	params.host_addr = (uint64_t) data;
	params.btt = no_of_bytes;

#if (INPUT_TESTS == 1)
	if(params.fpga_addr < USER_ADDRESS_OFFSET || params.fpga_addr >= 2*USER_ADDRESS_OFFSET || params.fpga_addr & 0x3) {
		WRN("Address out of valid memory location %lX", params.fpga_addr);
		return (platform_res_t) PERR_CTL_INVALID_ADDRESS;
	}

	if(params.btt & 0x3) {
		WRN("Byte size is not multiple of one register %d", params.btt);
		return (platform_res_t) PERR_CTL_INVALID_SIZE;
	}

	if(params.btt != 4) {
		LOG(LPLL_CTL, "Reading more than one register could cause errors %d", params.btt);
	}
#endif

	err = read(pcie_platform.fd_user[0], &params, sizeof(struct user_rw_params));

	if(err) {
		WRN("Read went wrong with error %d", err);
		return (platform_res_t) PERR_USER_SYS_CALL;
	}

	LOG(LPLL_CTL, "Read data %X from address %lX with length %d", *((uint32_t *) data), params.fpga_addr, params.btt);

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl(platform_ctx_t *ctx, platform_ctl_addr_t const start_addr, size_t const no_of_bytes, void const*data, platform_ctl_flags_t const flags)
{
	int err;
	struct user_rw_params params { 0 };
	if ((start_addr & 0xFFFF0000) == ATSPRI_ADDRESS || flags == PLATFORM_CTL_FLAGS_RAW)
	  params.fpga_addr = start_addr;
	else
	  params.fpga_addr = start_addr + USER_ADDRESS_OFFSET;
	params.host_addr = (uint64_t) data;
	params.btt = no_of_bytes;

#if (INPUT_TESTS == 1)
	if(params.fpga_addr < USER_ADDRESS_OFFSET || params.fpga_addr >= 2*USER_ADDRESS_OFFSET || params.fpga_addr & 0x3) {
		WRN("Address out of valid memory location %lX", params.fpga_addr);
		return (platform_res_t) PERR_CTL_INVALID_ADDRESS;
	}

	if(params.btt & 0x3) {
		WRN("Byte size is not multiple of one register %d", params.btt);
		return (platform_res_t) PERR_CTL_INVALID_SIZE;
	}

	if(params.btt != 4) {
		LOG(LPLL_CTL, "Reading more than one register could cause errors %d", params.btt);
	}
#endif

	LOG(LPLL_CTL, "Write data %X from address %lX with length %d", *((uint32_t *) data), params.fpga_addr, params.btt);
	err = write(pcie_platform.fd_user[0], &params, sizeof(struct user_rw_params));

	if(err) {
		WRN("Write went wrong with error %d", err);
		return  (platform_res_t) PERR_USER_SYS_CALL;
	}

	return PLATFORM_SUCCESS;
}

platform_res_t platform_write_ctl_and_wait(platform_ctx_t *ctx, platform_ctl_addr_t const w_addr, size_t const w_no_of_bytes, void const *w_data, uint32_t const event, platform_ctl_flags_t const flags)
{
	int err = -ENOENT;
	struct user_ioctl_params params { 0 };
	params.fpga_addr = w_addr + USER_ADDRESS_OFFSET;
	params.data = *((uint32_t *) w_data);
	params.event = (uint32_t) event;

#if (INPUT_TESTS == 1)
	if(params.fpga_addr < USER_ADDRESS_OFFSET || params.fpga_addr >= 2*USER_ADDRESS_OFFSET || params.fpga_addr & 0x3) {
		WRN("Address out of valid memory location %lX", params.fpga_addr);
		return (platform_res_t) PERR_CTL_INVALID_ADDRESS;
	}
	if(w_no_of_bytes != 4) {
		WRN("Writing more than one regiser is not permitted %ld", w_no_of_bytes);
		return (platform_res_t) PERR_CTL_INVALID_SIZE;
	}
	if(event >= MAX_SLOTS) {
		WRN("Invalid event number %d", event);
		return (platform_res_t) PERR_CTL_INVALID_SIZE;
	}
#endif

	LOG(LPLL_CTL, "Write data %X to address %lX with length %ld and event %d", params.data, params.fpga_addr, w_no_of_bytes, event);

	err = ioctl(pcie_platform.fd_user[0], IOCTL_CMD_USER_WAIT_EVENT, &params);

	if(err) {
		WRN("Ioctl went wrong with error %d", err);
		return  (platform_res_t) PERR_USER_SYS_CALL;
	}

	return PLATFORM_SUCCESS;
}
