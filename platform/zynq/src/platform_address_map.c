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
 *  @file	platform_address_map.c
 *  @brief	Implementation for platform API address calls.
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include <platform.h>

platform_ctl_addr_t platform_address_get_slot_base(
		platform_slot_id_t const slot_id,
		platform_slot_region_id_t const region_id)
{
	// TODO region_id is ignored, should be fixed for multi-slave Functions
	return 0x43c00000 + slot_id * 0x00010000;
}

platform_ctl_addr_t platform_address_get_special_base(
		platform_special_ctl_t const ent)
{
	switch (ent) {
	// TPC Status IP core is fixed at 0x7777_0000
	case PLATFORM_SPECIAL_CTL_STATUS: return 0x77770000;
	case PLATFORM_SPECIAL_CTL_INTC0 : return 0x81800000;
	case PLATFORM_SPECIAL_CTL_INTC1 : return 0x81810000;
	case PLATFORM_SPECIAL_CTL_INTC2 : return 0x81820000;
	case PLATFORM_SPECIAL_CTL_INTC3 : return 0x81830000;
	case PLATFORM_SPECIAL_CTL_ATSPRI: return 0xFFFFFFFF;
	}
	return 0;
}
