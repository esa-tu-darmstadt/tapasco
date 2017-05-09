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
//! @file	zynq_logging.h
//! @brief	Kernel logging for zynq TPC Platform. Defines logbits for
//!		subsystem debug.
//! @authors	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
//!
#ifndef __ZYNQ_LOGGING_H__
#define __ZYNQ_LOGGING_H__

#include "logging.h"

#define ZYNQ_LOGLEVELS \
	_ZLL(MODULE    , (1 << 1)) \
	_ZLL(DEVICE    , (1 << 2)) \
	_ZLL(IOCTL     , (1 << 3)) \
	_ZLL(DMAMGMT   , (1 << 4)) \
	_ZLL(FOPS      , (1 << 5)) \
	_ZLL(IRQ       , (1 << 6)) \
	_ZLL(ENTEREXIT , (1 << 31))

typedef enum {
#define _ZLL(name, level) ZYNQ_LL_##name = level,
ZYNQ_LOGLEVELS
#undef _ZLL
} zynq_ll_t;

#endif /* __ZYNQ_LOGGING_H__ */
