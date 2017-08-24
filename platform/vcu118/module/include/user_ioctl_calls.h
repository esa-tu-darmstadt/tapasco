//
// Copyright (C) 2014 David de la Chevallerie, TU Darmstadt
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
/**
 * @file user_ioctl_calls.c
 * @brief Define all ioctl commands with corresponding structs for user calls
	this allows simplified setup of kernel functions in the bitstream composition
	Two mechanisms are implemented: make use of read/write system calls to access registers,
	make use of ioctl to start a (hw-)function in blocking mode
 * */

#ifndef __USER_IOCTL_CALLS_H
#define __USER_IOCTL_CALLS_H

/******************************************************************************/

#include <linux/ioctl.h>

/******************************************************************************/

/* Maximal size of Parameter array for ioctl (type uint32_t) */
#define IOCTL_USER_MAX_PARAM_SIZE 4

struct user_ioctl_params {
	uint64_t fpga_addr;
	uint32_t data;
	uint32_t event;
};

/* struct used for read/write calls */
struct user_rw_params {
	uint64_t host_addr;
	uint64_t fpga_addr;
	uint32_t btt;
};

/* Magic character for unique identification */
#define USER_ID_GROUP_BLOCKING 'b'

/******************************************************************************/
/* ids and corresponding sizes for every call */

#define USER_ID_0	0
#define USER_SIZE_0	uint32_t[IOCTL_USER_MAX_PARAM_SIZE] /* fpga_mem_addr - data */

/******************************************************************************/
/* definition of cmds with _IOWR wrapper function to get system-wide unique numbers */

#define IOCTL_CMD_USER_WAIT_EVENT _IOR(USER_ID_GROUP_BLOCKING, USER_ID_0, USER_SIZE_0)

/******************************************************************************/

#endif // __USER_IOCTL_CALLS_H
