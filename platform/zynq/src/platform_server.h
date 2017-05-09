//
// Copyright (C) 2014 Jens Korinth, TU Darmstadt
//
// This file is part of ThreadPoolComposer (TPC).
//
// ThreadPoolComposer is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// ThreadPoolComposer is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with ThreadPoolComposer.  If not, see <http://www.gnu.org/licenses/>.
//
//! @file	platform_server.h
//! @brief	Internal configuration for DPI/socket platform libs.
//! @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//! @copyright  Copyright 2014, 2015 J. Korinth
//!
//!		This file is part of ThreadPoolComposer (TPC).
//!
//!  		ThreadPoolComposer is free software: you can redistribute it
//!		and/or modify it under the terms of the GNU Lesser General
//!		Public License as published by the Free Software Foundation,
//!		either version 3 of the License, or (at your option) any later
//!		version.
//!
//!  		ThreadPoolComposer is distributed in the hope that it will be
//!		useful, but WITHOUT ANY WARRANTY; without even the implied
//!		warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//!		See the GNU Lesser General Public License for more details.
//!
//!  		You should have received a copy of the GNU Lesser General Public
//!		License along with ThreadPoolComposer.  If not, see
//!		<http://www.gnu.org/licenses/>.
//!
#ifndef __PLATFORM_SERVER_H__
#define __PLATFORM_SERVER_H__

#include <module/zynq_platform.h>

#define MAX_SOCKETS					(256)
#define MAX_ID						(64)
#define ID_BITMASK					(0x3f)
#define MAX_INTC					ZYNQ_PLATFORM_INTC_NUM
#define INTC_BASE					ZYNQ_PLATFORM_INTC_BASE
#define INTC_OFFS					ZYNQ_PLATFORM_INTC_OFFS

#define SLOTS_BASE					(0x43C00000)
#define SLOTS_OFFS					(0x00100000)
#define SLOTS_END					(SLOTS_BASE + 128 * SLOTS_OFFS)

#endif /* __PLATFORM_SERVER_H__ */

