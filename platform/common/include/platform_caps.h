//
// Copyright (C) 2018 Jens Korinth, TU Darmstadt
//
// This file is part of Tapasco (PLATFORM).
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
 *  @file	platform_status.h
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#ifndef PLATFORM_CAPS_H__
#define PLATFORM_CAPS_H__

typedef enum {
	PLATFORM_CAP0_ATSPRI 			   	= (1 << 0),
	PLATFORM_CAP0_ATSCHECK 				= (1 << 1),
	PLATFORM_CAP0_PE_LOCAL_MEM 			= (1 << 2),
	PLATFORM_CAP0_DYNAMIC_ADDRESS_MAP		= (1 << 3),
} platform_capabilities_0_t;

#define PLATFORM_VERSION_MAJOR(v) 			((v) >> 16)
#define PLATFORM_VERSION_MINOR(v) 			((v) & 0xFFFF)

#endif /* PLATFORM_CAPS_H__ */
