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
//! @file	zynq_platform.h
//! @brief	General configuration parameters for zynq TPC Platform.
//! authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __ZYNQ_PLATFORM_H__
#define __ZYNQ_PLATFORM_H__

#include <platform_global.h>

#ifndef PLATFORM_API_TAPASCO_STATUS_SIZE
#define PLATFORM_API_TAPASCO_STATUS_SIZE	(0x00002000UL)
#endif

#define	ZYNQ_PLATFORM_MAXMEMHANDLES	((unsigned int)1024)
#define ZYNQ_PLATFORM_DEVFILENAME	"tapasco_platform_zynq"
#define ZYNQ_PLATFORM_MEMHANDLEFILENAME	ZYNQ_PLATFORM_DEVFILENAME "_mem"
#define ZYNQ_PLATFORM_WAITFILENAME	ZYNQ_PLATFORM_DEVFILENAME "_async"

#define ZYNQ_PLATFORM_GP0_BASE		(0x40000000UL)
#define ZYNQ_PLATFORM_GP1_BASE		(0x80000000UL)
#define ZYNQ_PLATFORM_GPX_SIZE		(0x10000000UL)

#define ZYNQ_PLATFORM_INTC_BASE		(0x81800000UL)
#define ZYNQ_PLATFORM_INTC_OFFS		(0x00010000UL)
#define ZYNQ_PLATFORM_INTC_MAX_NUM	(4)

#endif /* __ZYNQ_PLATFORM_H__ */
