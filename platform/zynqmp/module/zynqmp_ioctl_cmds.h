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
/**
 *  @file	zynqmp_ioctl_cmds.h
 *  @brief	
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef __ZYNQ_IOCTL_CMDS_H__
#define __ZYNQ_IOCTL_CMDS_H__

#include <linux/ioctl.h>

struct zynqmp_ioctl_cmd_t {
	void 			*data;
	size_t 			 length;
	long		 	 id;
	unsigned long		 dma_addr;
};

#define ZYNQ_IOCTL_FN			"tapasco_platform_zynqmp_control"

#define	ZYNQ_IOCTL_COPYTO		_IOWR('z', 1, struct zynqmp_ioctl_cmd_t)
#define	ZYNQ_IOCTL_COPYFROM		_IOWR('z', 2, struct zynqmp_ioctl_cmd_t)
#define	ZYNQ_IOCTL_ALLOC		_IOWR('z', 3, struct zynqmp_ioctl_cmd_t)
#define	ZYNQ_IOCTL_FREE			_IOWR('z', 4, struct zynqmp_ioctl_cmd_t)
#define	ZYNQ_IOCTL_COPYFREE		_IOWR('z', 5, struct zynqmp_ioctl_cmd_t)

#endif /* __ZYNQ_IOCTL_CMDS_H__ */
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
