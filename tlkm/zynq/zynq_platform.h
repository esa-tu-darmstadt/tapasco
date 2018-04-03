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
//! @file	zynq_platform.h
//! @brief	General configuration parameters for zynq platform.
//! authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef ZYNQ_PLATFORM_H__
#define ZYNQ_PLATFORM_H__

#include <platform_global.h>

#define ZYNQ_NAME			"xlnx,zynq-7000"

#define ZYNQ_PLATFORM_STATUS_BASE	0x77770000
#define ZYNQ_PLATFORM_STATUS_SIZE	0x00002000
#define ZYNQ_PLATFORM_STATUS_HIGH	(ZYNQ_PLATFORM_STATUS_BASE + \
		ZYNQ_PLATFORM_STATUS_SIZE)

#define ZYNQ_PLATFORM_GP0_BASE		0x42000000
#define ZYNQ_PLATFORM_GP0_SIZE		0x0e000000
#define ZYNQ_PLATFORM_GP0_HIGH		(ZYNQ_PLATFORM_GP0_BASE +\
		ZYNQ_PLATFORM_GP0_SIZE)

#define ZYNQ_PLATFORM_GP1_BASE		0x81000000
#define ZYNQ_PLATFORM_GP1_SIZE		0x02000000
#define ZYNQ_PLATFORM_GP1_HIGH		(ZYNQ_PLATFORM_GP1_BASE +\
		ZYNQ_PLATFORM_GP1_SIZE)

#define ISBETWEEN(a, l, h) (((a) >= (l) && (a) < (h)))

#endif /* ZYNQ_PLATFORM_H__ */
